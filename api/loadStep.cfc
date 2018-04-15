<cfcomponent output="false" extends="rollOutBase">
	<cfscript>
	
	remote string function view() returnFormat="plain" output="false" {
		var local = {};

		local.step = createObject("component","steps.step").init();

		return local.step.render();
	}

	
	</cfscript>
</cfcomponent>