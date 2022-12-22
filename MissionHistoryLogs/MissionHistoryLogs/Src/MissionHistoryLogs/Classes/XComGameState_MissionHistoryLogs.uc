// This is an Unreal Script
/*
	Author: Beat
	Had to create a XComGameState because StaticSaveConfig() was causing a crash.
*/
class XComGameState_MissionHistoryLogs extends XComGameState_BaseObject;

// 5 of these are on the top. MissionImagePath is non-negotiable
// Another 5 on the bottom
// 10 of these will be used, the rest are irrelevant.
struct MissionHistoryLogsDetails {
	var int CampaignIndex;
	var int EntryIndex; // This is to keep track of where the entry was added into the CurrentEntries array;
	var int SoldiersDeployed;
	var int SoldiersKilled;
	var string SuccessRate;
	var float wins;
	var string Date;
	var string MissionName;
	var string MissionObjective;
	var string MapName;
	var string MapImagePath;
	var string Squad;
	var string Enemies;
	var string ChosenName;
	var string QuestGiver; // Reapers, Skirmishers, Templars, The Council
	var string MissionRating; // Poor, Good, Fair, Excellent, Flawless.
	var string MissionLocation; // city and country of the mission
};

struct ChosenInformation {
	var string ChosenType;
	var string ChosenName;
	var int numEncounters;
	var int CampaignIndex;
};

struct SquadInformation {
	var string SquadName;
	var float numMissions; // declare as float for easier math later
	var float numWins;
};


var array<MissionHistoryLogsDetails> TableData;
// fireaxis why
var array<ChosenInformation> TheChosen;

var array<SquadInformation> SquadData;


function UpdateTableData() {
	local int injured, captured, killed, total;
	local StateObjectReference UnitRef;
	local XComGameState_Unit Unit;
	local string rating;
	local XComGameState_BattleData BattleData;
	local XComGameState_CampaignSettings CampaignSettingsStateObject;
	local XComGameState_HeadquartersAlien AlienHQ;
	local int CampaignIndex, MapIndex;
	local MissionHistoryLogsDetails ItemData;
	local X2MissionTemplateManager MissionTemplateManager;
	local X2MissionTemplate MissionTemplate;
	local array<PlotDefinition> ValidPlots;
	local XComParcelManager ParcelManager;
	local XComGameStateHistory History;
	local XComGameState_MissionSite MissionDetails;
	local XComGameState_ResistanceFaction Faction;
	local XComGameState_AdventChosen ChosenState;
	local ChosenInformation MiniBoss;
	local int Index;
	local string ChosenName;
	local XComGameState_LWSquadManager SquadMgr;
	local XComGameState_LWPersistentSquad Squad;

	injured = 0;
	captured = 0;
	killed = 0;
	total = 0;
	// Units can be both captured and injured as well as according to the game.
	// Units can be dead and injured according to the game (I think) if(arrUnits[i].kAppearance.bGhostPawn)?
	foreach `XCOMHQ.Squad(UnitRef)
	{
		Unit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitRef.ObjectID));
		if (Unit.WasInjuredOnMission()) {
			injured++;
		}
		if (Unit.bCaptured) {
			captured++;
		} else if (Unit.IsDead()) {
			killed++;
		}
		total++;

	}
	rating = GetMissionRating(injured, captured, killed, total);

	CampaignSettingsStateObject = XComGameState_CampaignSettings(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_CampaignSettings', true));
	CampaignIndex = CampaignSettingsStateObject.GameIndex;
	MissionDetails = XComGameState_MissionSite(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_MissionSite', true));
	// This will get the correct squad on a mission
	if(IsModActive('SquadManager')) {
		SquadMgr = XComGameState_LWSquadManager(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_LWSquadManager', true));
		// Squad = SquadMgr.GetSquadAfterMission(MissionDetails.ObjectID);
		Squad = XComGameState_LWPersistentSquad(`XCOMHISTORY.GetGameStateForObjectID(SquadMgr.LastMissionSquad.ObjectID));
		`log("what is squad name"@Squad.sSquadName);
		if (Squad.sSquadName != "") {
			ItemData.Squad = Squad.sSquadName;
		} else {
			`log("The squad name is empty for some reason");
			ItemData.Squad = "XCOM";
		}
	} else {
		// can also take approach of listing Unit nicknames that were on the mission.
		ItemData.Squad = "XCOM";
	}
	AlienHQ = XComGameState_HeadquartersAlien(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_HeadquartersAlien', true));
	`log("AlienHQ retrieved");
	Faction = XComGameState_ResistanceFaction(`XCOMHISTORY.GetGameStateForObjectID(MissionDetails.ResistanceFaction.ObjectID));
	`log("Faction Retrieved");
	ChosenState = XComGameState_AdventChosen(`XCOMHISTORY.GetGameStateForObjectID(AlienHQ.LastAttackingChosen.ObjectID));
	`log("Chosen retrieved");
	MissionTemplateManager = class'X2MissionTemplateManager'.static.GetMissionTemplateManager();
	`log("Mission Template Manager Retrieved");
	History = class'XComGameStateHistory'.static.GetGameStateHistory();
	`log("History Retrieved");
	// we need to keep track of this because any variable that could help us do this is only valid in the tactical layer.
	// for some reason when it gets to strategy, any variable that could help us determine if the chosen was on the most recent mission gets wiped.
	if (ChosenState.FirstName == "") {
		`log("there wa no chosen");
		ItemData.Enemies = "Advent";
	}
	else if (ChosenState.numEncounters == 1) {
		`log("our first encounter with this chosen");
		MiniBoss.ChosenType = string(ChosenState.GetMyTemplateName());
		MiniBoss.ChosenType = Split(MiniBoss.ChosenType, "_", true);
		MiniBoss.ChosenName = ChosenState.FirstName $ " " $ ChosenState.NickName $ " " $ ChosenState.LastName;
		MiniBoss.numEncounters = 1;
		MiniBoss.CampaignIndex = CampaignIndex;
		TheChosen.AddItem(MiniBoss);
		ItemData.ChosenName = MiniBoss.ChosenName;
		ItemData.Enemies = MiniBoss.ChosenType;
	} else if (ChosenState.numEncounters > 1) {
		`log("we've encountered them before");
		for (Index = 0; Index < TheChosen.Length; Index++) {
			ChosenName = ChosenState.FirstName $ " " $ ChosenState.NickName $ " " $ ChosenState.LastName;
			if (TheChosen[Index].CampaignIndex == CampaignIndex && TheChosen[Index].ChosenName == ChosenName && TheChosen[Index].numEncounters != ChosenState.numEncounters) {
				TheChosen[Index].numEncounters = ChosenState.numEncounters;
				ItemData.ChosenName = ChosenState.FirstName $ " " $ ChosenState.NickName $ " " $ ChosenState.LastName;
				ItemData.Enemies = TheChosen[Index].ChosenType;
				break;
			}
		}
	} else {
		`log("Some weird case we didn't cover");
		ItemData.Enemies = "Advent";
	}

	BattleData = XComGameState_BattleData(History.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	`log("got battle data");
	MissionTemplate = MissionTemplateManager.FindMissionTemplate(BattleData.MapData.ActiveMission.MissionName);
	`log("Got mission template");
	ParcelManager = `PARCELMGR;
	ParcelManager.GetValidPlotsForMission(ValidPlots, BattleData.MapData.ActiveMission);

	for( MapIndex = 0; MapIndex < ValidPlots.Length; MapIndex++ )
	{
		if( ValidPlots[MapIndex].MapName == BattleData.MapData.PlotMapName )
		{
			ItemData.MapName = class'UITLE_SkirmishModeMenu'.static.GetLocalizedMapTypeName(ValidPlots[MapIndex].strType);
			ItemData.MapImagePath = `MAPS.SelectMapImage(ValidPlots[MapIndex].strType);
			continue;
		}
	}
	`log("got the parcel manager and map name and map image");
	ItemData.CampaignIndex = CampaignIndex;
	ItemData.EntryIndex = TableData.Length + 1;
	ItemData.Date = class 'X2StrategyGameRulesetDataStructures'.static.GetDateString(BattleData.LocalTime, true);
	ItemData.MissionName = BattleData.m_strOpName;
	// Gatecrasher's objective is the same as the op name and thats lame.
	if (BattleData.m_strOpName == "Operation Gatecrasher") {
		ItemData.MissionObjective = "Send a Message";
	} else {
		ItemData.MissionObjective = MissionTemplate.DisplayName;
	}
	ItemData.MissionLocation = BattleData.m_strLocation;
	ItemData.MissionRating = rating;
	// run this function now so the math doesn't get messed up.
	// we do this now so if they save scum after the fact nothing gets messed up in the "db"
	// CheckForDuplicates(ItemData);
	`log("duplicates were checked for");
	// win
	if (BattleData.AllStrategyObjectivesCompleted()) {
		`log("its a win");
		ItemData.wins = TableData[TableData.Length - 1].wins + 1.0;
		ItemData.SuccessRate = (ItemData.wins/ (TableData.Length + 1.0)) * 100 $ "%";
		`log("math has finished");
	} else {
	// loss
		`log("its a loss");
		ItemData.wins = TableData[TableData.Length - 1].wins;
		ItemData.SuccessRate = (TableData[TableData.Length - 1].wins / (TableData.Length + 1.0)) * 100 $ "%";
		`log("math has finished");
	}
	if (Faction.FactionName == "") {
		ItemData.QuestGiver = "The Council";
	} else {
		ItemData.QuestGiver = Faction.FactionName;
	}
	`log("faction name assigned");
	TableData.AddItem(ItemData);
	`log("everything was saved");
}

function bool IsModActive(name ModName)
{
    local XComOnlineEventMgr    EventManager;
    local int                   Index;

    EventManager = `ONLINEEVENTMGR;

    for (Index = EventManager.GetNumDLC() - 1; Index >= 0; Index--) 
    {
        if (EventManager.GetDLCNames(Index) == ModName) 
        {
            return true;
        }
    }
    return false;
}


function string GetMissionRating(int injured, int captured, int killed, int total)
{
	local int iKilled, iInjured, iPercentageKilled, iCaptured;
	local XComGameState_BattleData BattleData;

	BattleData = XComGameState_BattleData(`XCOMHISTORY.GetSingleGameStateObjectForClass(class'XComGameState_BattleData'));
	iKilled = killed;
	iCaptured = captured;
	iPercentageKilled = ((iKilled + iCaptured) * 100) / total;
	iInjured = injured;
	if (!BattleData.AllStrategyObjectivesCompleted()) {
		return "Poor";
	}
	else if((iKilled + iCaptured) == 0 && iInjured == 0)
	{
		return "Flawless";
	}
	else if((iKilled + iCaptured) == 0)
	{
		return "Excellent";
	}
	else if(iPercentageKilled <= 34)
	{
		return "Good";
	}
	else if(iPercentageKilled <= 50)
	{
		return "Fair";
	}
	else
	{
		return "Poor";
	}
}


DefaultProperties {
	bSingleton=true;
}