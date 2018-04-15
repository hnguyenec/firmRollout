<cfcomponent output="false" extends="rollOutBase">
	<cfscript>
	session.INPUT_DATA = {
		"name": "_input_data",
		"title": "Input basic data",
		"skipable": false
	};

	remote struct function initializeProcess() returnFormat="json" output="false" {
		var local = {};
		local.messages = [];

		local.folderName = 'steps';
		var stepsPath = '#GetDirectoryFromPath(GetCurrentTemplatePath())#..\#local.folderName#';
		local.stepsFolderExistence = directoryExists(stepsPath);

		arrayAppend(local.messages, {
			'message': '<li class="' & 
							(local.stepsFolderExistence ? ' ok' : ' error') &
						'">
							Folder <b>#local.folderName#</b> ' & (local.stepsFolderExistence ? ' exists' : ' not exist') & 
						'</li>',
			'result': local.stepsFolderExistence
		});

		if (local.stepsFolderExistence) {
			initUserSession();

			arrayAppend(local.messages, 
				application._.map(session.process[session.userId].configurationDefs, function(def) {
					if (!directoryExists("#stepsPath#\#def.name#")) {
						return {
							'message': '<li class="error">Missing data for step: #def.name#</li>',
							'result': false
						};
					}
				}) 
			);

			local.messages = application._.flatten(local.messages);
		}

		return {
			'result': local.stepsFolderExistence AND (arrayLen(local.messages) EQ 1),
			'messages': local.messages,
			'next': (local.stepsFolderExistence AND (arrayLen(local.messages) EQ 1)) ? 
				(session.process[session.userId]["currentStep"] EQ 0 ? 
					_generateStep(session.INPUT_DATA) : 
					_generateStep(session.process[session.userId].configurationDefs[session.process[session.userId]["currentStep"]]) ) :
				{}
		};
	}

	private function initUserSession() {
		session.process = {};
		local.currentPath=GetDirectoryFromPath(GetCurrentTemplatePath());
		local.configurations = deserializeJSON(fileRead("#local.currentPath#..\steps\rolloutConfigurations.json"));
		session.process[session.userId] = {
			"currentStep": 0,
			"configurationDefs": local.configurations
		};

		// check outstanding step
		// one userId should has only one outstanding process
		local.outstandingProcess = entityLoad( "process", { userId: session.userId, isFinish: 0 });

		if (arrayLen(local.outstandingProcess) GT 0) {
			session.process[session.userId]["currentStep"] = local.outstandingProcess[1].getCurrentStep();
		}

	}

	private function _generateStep(struct stepDef) {
		var local = {};
		local.payload = {
			"iss": application.issuer,
			"aud": application.clientId,
			"user": session.userId,
			"step": arguments.stepDef.name
		};

		return {
			'token': application.jwt.encode(local.payload),
			'name': arguments.stepDef.name
		};
	}
	</cfscript>
</cfcomponent>