component persistent="true" table="firmCreationStep" {

	property name="id" fieldtype="id" generator="increment";

	property name="userId" ormtype="int";     
	//property name="firmId" ormtype="int";
	property name="currentStep" ormtype="int";
	property name="createdDate" ormtype="timestamp";
	property name="updatedDate" ormtype="timestamp";
	property name="isFinish" ormtype="boolean";  

	property name="firm" fieldtype="one-to-one" cfc="firms" fkcolumn="firmId";

}