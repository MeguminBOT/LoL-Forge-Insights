package forge.data;

typedef ChampionSpell = {
	var id:String;
	var name:String;
	var description:String;
	var tooltip:String;
	var maxrank:Int;
	var costType:String;
	var datavalues:Dynamic;
	var effect:Array<Float>;
	var vars:Array<Dynamic>;
}
