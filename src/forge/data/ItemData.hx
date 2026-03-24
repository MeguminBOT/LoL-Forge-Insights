package forge.data;

typedef ItemData = {
	var name:String;
	var description:String;
	var image:ImageData;
	var gold:ItemGold;
	var tags:Array<String>;
	var maps:Dynamic;
	var stats:Dynamic;
	var ?from:Array<String>;
	var ?into:Array<String>;
	var ?depth:Int;
	var ?consumed:Bool;
	var ?inStore:Bool;
	var ?hideFromAll:Bool;
	var ?requiredChampion:String;
	var ?requiredAlly:String;
	var ?effect:Dynamic;
	var ?pickRate:Float; // optional from telemetry / analytics feed
}
