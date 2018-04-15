component persistent="true" table="firms"{
	property name="id" fieldtype="id" generator="increment";
	property name="firmName" ormtype="text";   
	property name="process" fieldtype="one-to-one" cfc="process" mappedby="firm";
}