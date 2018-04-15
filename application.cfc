<cfcomponent output="false">
    
    <cfscript>
        this.name = determineApplicationName();
        this.sessionManagement = true;
        this.applicationTimeout = createTimeSpan(0,10,0,0);
        this.clientmanagement= "false";
        this.loginstorage = "session" ;
        this.sessiontimeout = createTimeSpan(0,1,30,0); // 1 hour and 30 minutes
        this.setClientCookies = "yes";
        this.setDomainCookies = "no";
        this.scriptProtect = "all";

        this.rootDir = getDirectoryFromPath(getCurrentTemplatePath() );
        this.mappings["/fullspectrum_path"] = this.rootDir;
        this.mappings["/steps"] = "#this.rootDir#steps/";
        this.mappings["/cfcs"] = "#this.rootDir#cfcs/";
        this.mappings["/public"] = "#this.rootDir#public/";
        this.mappings["/api"] = "#this.rootDir#api/";

        // jwt
        this.secretKey = 'huyatu';
        this.clientId = createUUID();
        this.issuer = 'https://github.com/hnguyenec';

        // ORM
        this.ormEnabled = true;
        this.datasource = "firmRolloutDSN";
        
        /* 
        When ORM is enabled, by default, ColdFusion will scan from your web root, looking for any CFC’s that are marked as persistent. 
        As a performance enhancement, it’s useful to tell it specifically what folder to look at.  
        Also, if you have your components stored in a mapped directory, this is the only way it can be done.
         */
        this.ormSettings.cfcLocation = ["/cfcs/models"];

        /* 
        Turns off the Hibernate session being flushed at the end of the request
        Stops the Hibernate session being flushed at the beginning of a transaction
        Stops the Hibernate session being cleared when a transaction is rolled back
         */
        this.ormSettings.automanageSession = false;
        this.ormSettings.flushatrequestend = false;

        this.ormSettings.useDBForMapping = false;
        //this.ormSettings.autogenmap = false;
        this.ormSettings.logSQL = true;
        this.ormsettings.dialect="MicrosoftSQLServer";
                        
    </cfscript>


    <cffunction name="determineApplicationName" output="false">
      <cfscript>
            var path=GetDirectoryFromPath(GetCurrentTemplatePath());
            var path_len=ListLen(path,"\/");
            var parent_dir=ListGetAt(path, path_len-1,"\/");
            if (parent_dir contains ".")
                return parent_dir; // ie fsr.cvmailau.com.au_fullspectrum
            else
                return parent_dir & "_" & listfirst(cgi.script_name,"/");   //ie "cvMailFSR_vel-4_24_patches_fullspectrum"
      </cfscript>
   </cffunction>

   <cffunction name="initComponents" returnType="void" output="false">
        <cftry>
            <cfif !StructKeyExists(application, "underscore") >
                <cfset application._ = createObject("component","cfcs.libs.underscore").init()>
            </cfif>
            <cfif !StructKeyExists(application, "jwt") >
                <cfset application.issuer = this.issuer />
                <cfset application.clientId = this.clientId />

                <cfset application.jwt = createObject("component","cfcs.libs.cf_jwt")
                    .init(
                        secretKey = this.secretKey,
                        issuer    = this.issuer,
                        audience  = this.clientId
                    )
                />
            </cfif>
        <cfcatch>
            <cfdump var="#cfcatch#" format="html" output="c:\temp\test.html" >
        </cfcatch>    
        </cftry>
        
   </cffunction>

    <cffunction name="onApplicationStart" returnType="boolean" output="false">
        <cftry>
            <!--- set your app vars for the application --->
            <cfscript>
                application.sessions = 0;
                local = structNew();
            </cfscript>

            <!---
                Create a cache for our API objects. Each object will
                be cached at it's name/path such that each remote
                method call does NOT have to mean a new ColdFusion
                component instantiation.
            --->
            <cfset application.apiCache = {} />
            
            <!--- <cfif !StructKeyExists(application, "portalSettingsService") OR application.global_reset EQ 1>
                <cfset application.portalSettingsService = createObject("component","cfcs.cvmail.portalSettings.portalSettingsService").init()>
            </cfif> --->
            
            <cfset initComponents() />
            <cfcatch>
                <cflog file="#this.name#" type="Error" text="error with buglogservice for #this.name# #cfcatch.message#">
            </cfcatch>
        </cftry>

        <cfreturn True>
    </cffunction>

     <cffunction name="onApplicationEnd" returnType="void" output="false">
          <cfargument name="applicationScope" required="true">
     </cffunction>

    <cffunction  name="onCFCRequest"  access="public" returntype="void">
        <!--- Define arguments. --->
        <cfargument name="component" type="string" required="true" />
        <cfargument name="methodName" type="string" required="true" />
        <cfargument name="methodArguments" type="struct" required="true" />

        <!---
            Check to see if the target CFC exists in our cache.
            If it doesn't then, create it and cached it.
        --->

        <cfif !structKeyExists( application.apiCache, arguments.component )>

            <!---
                Create the CFC and cache it via its path in the
                application cache. This way, it will exist for
                the life of the application.
            --->
            <cfset local.componentPath = "#determineApplicationName()#.fullspectrum">
            <cfset application.apiCache[ arguments.component ] = createObject("component",
                    ReplaceNoCase(arguments.component, local.componentPath, "fullspectrum_path") ) />
        </cfif>
        <!--- Get the target component out of the cache. --->
        <cfset local.cfc = application.apiCache[ arguments.component ] />
        <!---
            Create a default response data variable and mime-type.
            While all the values returned will be string, the
            string might represent different data structures.
        --->
        <cfset local.responseData = "" />
        <cfset local.responseMimeType = "text/plain" />
        <cfset local.status = false>
        <cfset local.header = {} />
        <cfset local.header["code"] = "400">
        <cfset local.header["text"] = "Bad Request">

        <cfset local.componentMetadata = getInheritedMetadata(local.cfc) />
        <cfset local.functionMetadata = getMetaData(local.cfc[arguments.methodName]) />
        <cfif (structKeyExists(local.functionMetadata, "access")) AND (local.functionMetadata.access EQ "remote")>
            <cfif ( structKeyExists(local.componentMetadata, "userMetadata")) AND (local.componentMetadata.userMetadata EQ "masterRequired") >
                <cfif (structkeyExists(session, "cvmail_system_admin")) AND (session.cvmail_system_admin) >
                    <!---
                        Execute the remote method call and store the response
                    --->
                    <cfset local.header["code"] = "200">
                    <cfset local.header["text"] = "OK">
                    <cfset local.status = true>
                    <cfinvoke
                        returnvariable="local.result"
                        component="#local.cfc#"
                        method="#arguments.methodName#"
                        argumentcollection="#arguments.methodArguments#"
                        />
                <cfelse>
                    <cfset local.header["code"] = "401">
                    <cfset local.header["text"] = "Unauthorised">
                </cfif>
            <cfelseif ( structKeyExists(local.componentMetadata, "userMetadata")) AND (local.componentMetadata.userMetadata EQ "userRequired") >
                 <cfif (structkeyExists(session, "user_id"))>
                    <!---
                        Execute the remote method call and store the response
                    --->
                    <cfset local.header["code"] = "200">
                    <cfset local.header["text"] = "OK">
                    <cfset local.status = true>
                    <cfinvoke
                        returnvariable="local.result"
                        component="#local.cfc#"
                        method="#arguments.methodName#"
                        argumentcollection="#arguments.methodArguments#"
                        />
                <cfelse>
                    <cfset local.header["code"] = "401">
                    <cfset local.header["text"] = "Unauthorised">
                </cfif>
            <cfelse>
                <!--- No user restriction--->
                <cfset local.header["code"] = "200">
                <cfset local.header["text"] = "OK">
                <cfset local.status = true>
                <cfinvoke
                    returnvariable="local.result"
                    component="#local.cfc#"
                    method="#arguments.methodName#"
                    argumentcollection="#arguments.methodArguments#"
                    />
            </cfif>
        <cfelse>
            <cfset local.header["code"] = "404">
            <cfset local.header["text"] = "Not Found">
        </cfif>

        <!---
            Check to see if the method call above resulted in any
            return value. If it didn't, then we can just use the
            default response value and mime type.
        --->
        <cfif structKeyExists( local, "result" )>
            <!---
                Check to see what kind of return format we need to
                use in our transformation. Keep in mind that the
                URL-based return format takes precedence. As such,
                we're actually going to PARAM the URL-based format
                with the default in the function. This will make
                our logic much easier to follow.
                NOTE: This expects the returnFormat to be defined
                on your CFC - a "best practice" with remote
                method definitions.
            --->
            <cfparam name="url.returnFormat" type="string" default="#structkeyexists(getMetaData( local.cfc[ arguments.methodName ] ), 'returnFormat') ? getMetaData( local.cfc[ arguments.methodName ] ).returnFormat : 'json'#" />
            <cfif (url.returnFormat eq "json")>
                <!--- Convert the result to json. --->
                 <cfif isstruct( local.result )>
                    <cfset local.responseData = serializeJSON( local.result ) />
                <cfelse>
                    <cfset local.responseData = duplicate( local.result ) />
                </cfif>   
                <!--- Set the appropriate mime type. --->
                <cfset local.responseMimeType = "text/x-json" />
            <cfelse>
                <!--- Convert the result to string. --->
                <cfset local.responseData = local.result />
                <!--- Set the appropriate mime type. --->
                <cfset local.responseMimeType = "text/plain" />
            </cfif>
        </cfif>

        <!--- Convert the response to binary. --->
        <cfset local.binaryResponse = toBinary(
            toBase64( local.responseData )
            ) />
        <!---
            Set the content length (to help the client know how
            much data is coming back).
        --->
        <cfif local.status>
            <cfheader
                name="content-length"
                value="#arrayLen( local.binaryResponse )#"
                />
        <cfelse>
            <cfheader
                statusCode = "#local.header.code#"
                statusText = "#local.header.text#"
                />
        </cfif>
        <!--- Stream the content. --->
        <cfcontent
            type="#local.responseMimeType#"
            variable="#local.binaryResponse#"
            />

        <cfreturn />
    </cffunction>



    <cffunction name="onRequestStart" returnType="boolean" output="false">
        <cfargument name="thePage" type="string" required="true">
        <cfsetting showdebugoutput="true">
        <cfscript>
            if (structKeyExists(url, "reset" ) AND url.reset eq "true"){
                structClear(application);
                OnApplicationStart();
                OnSessionStart();
                ORMReload();
            }
        </cfscript>
        <cfreturn true>
     </cffunction>

    <cffunction name="onRequest" returnType="void">
        <cfargument name="thePage" type="string" required="true">
        <cfinclude template="#arguments.thePage#">
    </cffunction>

    <cffunction name="onRequestEnd" returnType="void" output="false">
        <cfargument name="thePage" type="string" required="true">

    </cffunction>

    <cffunction name="onError" returnType="void" output="true">
        <cfargument name="Except" required=true/>
        <cfargument type="String" name = "EventName" required=true/>
        <!--- Log all errors in an application-specific log file. --->
        <cflog file="#This.Name#" type="error" text="Event Name: #arguments.Eventname#" >
        <cflog file="#This.Name#" type="error" text="Message: #arguments.except.message#">
        <cfset var errortext = "">
        <cfset var newUUID = createUUID()>
        <cfset var error = arguments.Except>

        <!--- Throw validation errors to ColdFusion for handling. --->
        <cfif Find("coldfusion.filter.FormValidationException", Arguments.Except.StackTrace)>
            <cfthrow object="#except#">
        <cfelse>
            <cfsavecontent variable="errortext">
                <cfoutput>
                    <p>Error Event: #EventName#</p>
                    <p>Error details:<br>
                    <cfdump var="#except#"></p>
                    <cfdump var="#session#">
                </cfoutput>
            </cfsavecontent>

            <cfoutput>#errortext#</cfoutput>

         </cfif>
    </cffunction>

    <cffunction name="onSessionStart" returnType="void" output="false">
        <cfset StructClear(Session)>
        <cfscript>
            session.started = now();
        </cfscript>

        <cflock scope="application" timeout="5" type="Exclusive">
            <cfset application.sessions = application.sessions + 1>
        </cflock>
    </cffunction>

    <cffunction name="onSessionEnd" returnType="void" output="false">
        <cfargument name="sessionScope" type="struct" required="true">
        <cfargument name="appScope" type="struct" required="false">

        <cfset var sessionLength = TimeFormat(Now() - sessionScope.started, "H:mm:ss")>

    </cffunction>

    <cffunction name="getInheritedMetaData" output="false" hint="Returns a single-level metadata struct that includes all items inhereited from extending classes.">
        <cfargument name="component" type="any" required="true" hint="A component instance, or the path to one">
        <cfargument name="md" default="#structNew()#" hint="A structure containing a copy of the metadata for this level of recursion.">
        <cfset var local = {}>

        <!--- First time through, get metaData of component.  --->
        <cfif structIsEmpty(md)>
            <cfif isObject(component)>
                <cfset md = getMetaData(component)>
            <cfelse>
                <cfset md = getComponentMetaData(component)>
            </cfif>
        </cfif>

        <!--- If it has a parent, stop and calculate it first, unless of course, we've reached a class we shouldn't recurse into. --->
        <cfif structKeyExists(md,"extends")>
            <cfset local.parent = getInheritedMetaData(component,md.extends)>
        <!--- If we're at the end of the line, it's time to start working backwards so start with an empty struct to hold our condensesd metadata. --->
        <cfelse>
            <cfset local.parent = {}>
            <cfset local.parent.inheritancetrail = []>
        </cfif>

        <!--- Override ourselves into parent --->
        <cfloop collection="#md#" item="local.key">
            <!--- Functions and properties are an array of structs keyed on name, so I can treat them the same --->
            <cfif listFind("FUNCTIONS,PROPERTIES", local.key)>
                <cfif not structKeyExists(local.parent,local.key)>
                        <cfset local.parent[local.key] = []>
                </cfif>
                <!--- For each function/property in me... --->
                <cfloop array="#md[local.key]#" index="local.item">
                    <cfset local.parentItemCounter = 0>
                    <cfset local.foundInParent = false>
                    <!--- ...Look for an item of the same name in my parent... --->
                    <cfloop array="#local.parent[local.key]#" index="local.parentItem">
                        <cfset local.parentItemCounter++>
                        <!--- ...And override it --->
                        <cfif compareNoCase(local.item.name,local.parentItem.name) eq 0>
                            <cfset local.parent[local.key][local.parentItemCounter] = local.item>
                            <cfset local.foundInParent = true>
                            <cfbreak>
                        </cfif>
                    </cfloop>
                    <!--- ...Or add it --->
                    <cfif not local.foundInParent>
                        <cfset arrayAppend(local.parent[local.key],local.item)>
                    </cfif>
                </cfloop>
                <!--- For everything else (component-level annotations), just override them directly into the parent --->
                <cfelseif NOT listFind("EXTENDS,IMPLEMENTS",local.key)>
                    <cfset local.parent[local.key] = md[local.key]>
            </cfif>
        </cfloop>
        <cfset arrayPrePend(local.parent.inheritanceTrail,local.parent.name)>
        <cfreturn local.parent>

    </cffunction>
</cfcomponent>
