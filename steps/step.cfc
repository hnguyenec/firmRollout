component implements="IStep" {

	function init() {
		return this;
	}

	function verify() {
		var local = {};
		local.result = {
			status: false,
			payload: {}
		};

		if (structKeyExists(getHTTPRequestData().headers, 'Authorization')) {
			local.token = listLast(getHTTPRequestData().headers.Authorization," ");
			try {
				local.payload = application.jwt.decode(local.token);

				if ( (local.payload.user EQ session.userId) AND 
					(structKeyExists(session.process, local.payload.user)) AND 
					( _getCurrentStepName(local.payload.user, session.process[local.payload.user].currentStep) EQ local.payload.step) 
				) {

					local.result.status = true;
					local.result.payload = local.payload;
				} 
			} catch (any ex) {
				local.result.status = false;
			}
			
		}

		return local.result;
	}

	function _getCurrentStepName(userId, stepIndex) {
		if (arguments.stepIndex EQ 0)
			return session.INPUT_DATA.name;
		return session.process[arguments.userId].configurationDefs[arguments.stepIndex].name;
	}

	function render() {
		var local = {};
		local.verify = verify();

		if (local.verify.status) {
			savecontent variable="local.step_content" { 
				include "#local.verify.payload.step#/views/main.cfm";
			}

			return local.step_content;
		} else {
			return '<div class="error">AUTHORISATION FAILED</div>';
		}
		
	}

	function submit() {

	}

	function next() {

	}
}