component {

    this.name = "Firm Rollout";
    this.applicationTimeout = CreateTimeSpan(10, 0, 0, 0); //10 days
    this.datasource = "firmRolloutDSN";
    this.sessionManagement = true;
    this.sessionTimeout = CreateTimeSpan(0, 0, 30, 0); //30 minutes
    this.customTagPaths = [ expandPath('/myAppCustomTags') ];
    this.mappings = {
        "cfcs" = expandPath('/cfcs'),
        "public" = expandPath('/public')
    };

    function onApplicationStart() {
        application.apiCache = {};
        return true;
    }

    function onSessionStart() {}

    // the target page is passed in for reference, 
    // but you are not required to include it
    function onRequestStart( string targetPage ) {}

    function onRequest( string targetPage ) {
        include arguments.targetPage;
    }

    private function determineApplicationName() {
            var path=GetDirectoryFromPath(GetCurrentTemplatePath());
            var path_len=ListLen(path,"\/");
            var parent_dir=ListGetAt(path, path_len-1,"\/");
            if (parent_dir contains ".")
                return parent_dir; // ie fsr.cvmailau.com.au_fullspectrum
            else
                return parent_dir & "_" & listfirst(cgi.script_name,"/");   //ie "cvMailFSR_vel-4_24_patches_fullspectrum"
    }

    function  onCFCRequest( string component, string methodName, struct methodArguments) {
        /* 
            Check to see if the target CFC exists in our cache.
            If it doesn't then, create it and cached it.
        */
        if (!structKeyExists( application.apiCache, arguments.component )) {
            local.componentPath = "#determineApplicationName()#.fullspectrum";
            application.apiCache[ arguments.component ] = createObject("component",
                    ReplaceNoCase(arguments.component, local.componentPath, "fullspectrum_path") );
        }

        local.cfc = application.apiCache[ arguments.component ];

        local.responseData = "" ;
        local.responseMimeType = "text/plain" ;
        local.status = false;
        local.header = {} ;
        local.header["code"] = "400";
        local.header["text"] = "Bad Request";

        local.componentMetadata = getInheritedMetadata(local.cfc);
        local.functionMetadata = getMetaData(local.cfc[arguments.methodName]);

        if ((structKeyExists(local.functionMetadata, "access")) AND (local.functionMetadata.access EQ "remote")){
            if ( (structKeyExists(local.componentMetadata, "userMetadata")) AND (local.componentMetadata.userMetadata EQ "masterRequired")) {
                if ( (structkeyExists(session, "cvmail_system_admin")) AND (session.cvmail_system_admin) ){
                    local.header["code"] = "200";
                    local.header["text"] = "OK";
                    local.status = true;
                    local.result = invoke(
                        local.cfc,
                        arguments.methodName,
                        arguments.methodArguments
                    );
                } else {
                    local.header["code"] = "401";
                    local.header["text"] = "Unauthorised";
                }
            } else {
                local.header["code"] = "200";
                local.header["text"] = "OK";
                local.status = true;
                local.result = invoke(
                    local.cfc,
                    arguments.methodName,
                    arguments.methodArguments
                );
            }
        } else {
            local.header["code"] = "404";
            local.header["text"] = "Not Found";
        }

        if (structKeyExists( local, "result" ) ) {
            param (name="url.returnFormat",
                type="string",
                default="#structkeyexists(getMetaData( local.cfc[ arguments.methodName ] ), 'returnFormat') ? getMetaData( local.cfc[ arguments.methodName ] ).returnFormat : 'json'#" 
            );
            if (url.returnFormat eq "json") {
                if (isstruct( local.result ) ) {
                    local.responseData = serializeJSON( local.result );
                } else {
                    local.responseData = duplicate( local.result ) ;
                }
                local.responseMimeType = "text/x-json" ;
            } else {
                local.responseData = local.result;
                local.responseMimeType = "text/plain";
            }
        }

        local.binaryResponse = toBinary(
            toBase64( local.responseData )
            );
        
        if (local.status) {
            header(
                name="content-length",
                value="#arrayLen( local.binaryResponse )#"
            );
        } else {
            header(
                statusCode = "#local.header.code#",
                statusText = "#local.header.text#"
            );
        }

        content(
            type="#local.responseMimeType#",
            variable="#local.binaryResponse#"
        );

        return;
        
    }        
       
    function onRequestEnd() {}

    function onSessionEnd( struct SessionScope, struct ApplicationScope ) {}

    function onApplicationEnd( struct ApplicationScope ) {}

    function onError( any Exception, string EventName ) {}

}