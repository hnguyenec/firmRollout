component {

	function init() {
		return this;
	}

	/**
	* Returns True if the specified folder (directory) exists on the ColdFusion server. (Windows only)
	* 
	* @param folder      Complete path (absolute or relative) to the folder whose existence you want to test.  
	* @return Returns a Boolean value. 
	*/
	function FolderExists(folder)
	{
		var fso  = CreateObject("COM", "Scripting.FileSystemObject");
		return fso.FolderExists(folder);
	}
}