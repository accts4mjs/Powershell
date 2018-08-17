$psISE.Options.ShowOutlining = $true
$psISE.Options.ShowDefaultSnippets = $true
$psISE.Options.ShowIntellisenseInScriptPane = $true
$psISE.Options.ShowIntellisenseInConsolePane = $true

# 
Set-Variable -Option AllScope -Name OptionSetter -Value (&{
	$ClassName = 'IndentFixer'
	$Namespace = 'ISEHijack'
	Add-Type @"
		internal class _Option<TValue>
		{
			public _Option(string key, TValue value)
			{
				Key = key;
				Value = value;
			}

			public Object[] Params { get { return new object[] { Key, Value }; } }
			public string Key { get; private set; }
			public TValue Value { get; private set; }
		}

		internal static object[] Opt<TVal>(string key, TVal value)
		{
			return new _Option<TVal>(key, value).Params;
		}
	
		internal static readonly object[][] NewOpts = {
			Opt<bool>("Adornments/HighlightCurrentLine/Enable", false),
			Opt<int>("Tabs/TabSize", 4),
			Opt<int>("Tabs/IndentSize", 4),
			Opt<bool>("Tabs/ConvertTabsToSpaces", false),
			Opt<bool>("TextView/UseVirtualSpace", false),
			Opt<bool>("TextView/UseVisibleWhitespace", true)
		};

		internal void SetOpts()
		{
			foreach(object[] args in NewOpts) {
				Setter.Invoke(Options, args);
			}
		}

		public MethodInfo Setter { get; set; }
		public object Options { get; set; }
		public Dispatcher EditorDispatcher { get; set; }
		public List<Action> Actions { get; private set; }

		public ${ClassName}()
		{
			Actions = new List<Action>();
			Actions.Add(SetOpts);
		}

		public void Dispatch(Dispatcher dispatcher)
		{
			DispatcherFrame frame = new DispatcherFrame();
			dispatcher.BeginInvoke(DispatcherPriority.Normal, new DispatcherOperationCallback(ExitFrames), frame);
			Dispatcher.PushFrame(frame);
		}

		private object ExitFrames(object f){
			DispatcherFrame frame = ((DispatcherFrame)f);
			// foreach(Action action in Actions) {
				// action.Invoke();
			// }
			// Actions.Clear();
            foreach(object[] args in NewOpts) {
				Setter.Invoke(Options, args);
			}
			frame.Continue = false;
			return null;
		}
"@  -Name $ClassName `
	-NameSpace $Namespace `
	-UsingNamespace System.Windows.Forms,System.Windows.Threading,System.Reflection,Microsoft.VisualStudio.Text.EditorOptions.Implementation,System.Collections.Generic `
	-ReferencedAssemblies WindowsBase,System.Windows.Forms,Microsoft.PowerShell.Editor
	return `
           "${Namespace}.${ClassName}" |
	       Add-Member -Type NoteProperty -Name Namespace -Value $Namespace -Passthru |
	       Add-Member -Type NoteProperty -Name ClassName -Value $ClassName -Passthru
})

[System.Reflection.BindingFlags] $NonPublicFlags = [System.Reflection.BindingFlags] 'NonPublic,Instance'

filter Expand-Property
{
	PARAM(
		[Alias('Property')]
		[ValidateNotNullOrEmpty()] 
		[Parameter(Mandatory, Position=0)]
		[String] $Name
	)
	$_ | Select-Object -ExpandProperty $Name | Write-Output
}

function Get-IsePrefs
{
	PARAM(
		[Parameter(Mandatory, Position=1)]
		[ValidateNotNullOrEmpty()]
		[string] $Key
	)
	$oEditor = $psISE.CurrentFile.Editor
	$tEditor = $oEditor.GetType()
	$tEditor.GetProperty('EditorOperations', $NonPublicFlags).GetMethod.Invoke($oEditor, $null).Options | `
		Expand-Property GlobalOptions | `
		Expand-Property SupportedOptions | `
		Select-Object -Property Key,ValueType,DefaultValue | `
		Write-Output
}

function Comment-Selection
{
	$output = ''
	$psISE.CurrentFile.Editor.SelectedText.Split("`n") | ForEach-Object -Process { $output += "# " + [string]$_ + "`n" }
	$psISE.CurrentFile.Editor.InsertText($output)
}

function Fix-EditorIndentation
{
	PARAM(
		[Alias('ISEEditor')][ValidateNotNull()]
		[Parameter(Mandatory, ValueFromPipeline, Position=1)]
		[Microsoft.PowerShell.Host.ISE.ISEEditor]
		$Editor
	)
	$EditorType = $Editor.GetType()
	$SetterInstance = New-Object -TypeName $OptionSetter
	$SetterInstance.Options = $EditorType.GetProperty('EditorOperations', $NonPublicFlags).GetMethod.Invoke($Editor, $null).Options
	$Dispatcher = $EditorType.GetProperty('EditorViewHost', $NonPublicFlags).GetMethod.Invoke($Editor, $null).Dispatcher
	$SetterInstance.Setter = $SetterInstance.Options.GetType().GetMethod('SetOptionValue',  [type[]]@([string],[object]))
	$SetterInstance.Dispatch($Dispatcher)
}

function Fix-IseIndentation
{
	[Microsoft.Windows.PowerShell.Gui.Internal.MainWindow] $ISEWindow = (Get-Host | Select-Object -ExpandProperty PrivateData | Select-Object -ExpandProperty Window)
	[Microsoft.Windows.PowerShell.Gui.Internal.RunspaceTabControl] $RSTabCtrl = $ISEWindow.Content[0].Children[2]
	[Microsoft.PowerShell.Host.ISE.PowerShellTab] $PSTab = $RSTabCtrl.Items[0]
	$PSTab.Files | Select-Object -ExpandProperty Editor | Fix-EditorIndentation
}

function Invoke-ISEFunction
{
	PARAM(
		[Parameter(Mandatory, Position=1)]
		[Action] $ScriptBlock
	)
	$ISEWindow = $(Get-Host | Select-Object -ExpandProperty PrivateData | Select-Object -ExpandProperty Window)
	return $ISEWindow.Dispatcher.Invoke($ScriptBlock)
}

function Fix-IndentationForAll
{
	 $psISE.PowerShellTabs | Select-Object -ExpandProperty 'Files' | Select-Object -ExpandProperty 'Editor' | Fix-EditorIndentation
}
# Startup

function New-Timer
{
	PARAM(
		[Alias('Handler')]
		[Parameter(Position=0, Mandatory=$true)]
		$Action,

		[Double]
		[Parameter(Mandatory=$false)]
		$Interval = 50,
		
		[Boolean]
		[Parameter(Mandatory=$false)]
		$AutoReset = $true
	)
	[System.Timers.Timer] $oTimer = New-Object -TypeName System.Timers.Timer($Interval)
	$ElapsedEvent = Register-ObjectEvent -InputObject $oTimer -EventName 'Elapsed' -Action $Action
	$oTimer.AutoReset = $AutoReset
	return $oTimer
}

$(New-Timer {
	Fix-IndentationForAll
} -Interval 100 -AutoReset $true).Start()