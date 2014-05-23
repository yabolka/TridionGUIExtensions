Type.registerNamespace("Extensions");
 
Extensions.BDelete = function Extensions$BDelete() {
    Type.enableInterface(this, "Extensions.BDelete");
    this.addInterface("Tridion.Cme.Command", ["BDelete"]);
};
 
Extensions.BDelete.prototype.isAvailable = function BDelete$isAvailable(selection) {
    return true;
}
 
Extensions.BDelete.prototype.isEnabled = function BDelete$isEnabled(selection) {
    if (selection.getItems().length > 1)
        return false;
    else
        return true;
}
 
Extensions.BDelete.prototype._execute = function BDelete$_execute(selection) {
    selectedItem = selection.getItems()[0];
    var inputId = selectedItem.substring(4);	
	
	function load(type, url, callback) {
			var xhr;
			 
			if(typeof XMLHttpRequest !== 'undefined') xhr = new XMLHttpRequest();
			else {
				var versions = ["MSXML2.XmlHttp.5.0", 
								"MSXML2.XmlHttp.4.0",
								"MSXML2.XmlHttp.3.0", 
								"MSXML2.XmlHttp.2.0",
								"Microsoft.XmlHttp"]
	 
				 for(var i = 0, len = versions.length; i < len; i++) {
					try {
						xhr = new ActiveXObject(versions[i]);
						break;
					}
					catch(e){}
				 } // end for
			}
			 
			xhr.onreadystatechange = ensureReadiness;
			 
			function ensureReadiness() {
				if(xhr.readyState < 4) {
					return;
				}
				 
				if(xhr.status !== 200) {
					return;
				}
	 
				// all is well  
				if(xhr.readyState === 4) {
					callback(xhr);
				}           
			}
			 
			xhr.open(type, url, true);
			xhr.send('');
		}
	
	if (confirm("Are you sure you want to delete the component and all of its children?")) {	
		
		load('DELETE', "http://localhost:1238/api/values/delete/" + inputId, function(){
			console.log('success');
		});
	}            
}
