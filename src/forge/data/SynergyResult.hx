package forge.data;

typedef SynergyResult = {
	var itemId:String;
	var score:Int; // 0-10
	var tier:SynergyTier;
	var reasons:Array<String>;
	var affectedAbilities:Array<String>;
}
