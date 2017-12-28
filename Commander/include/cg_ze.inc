#include <zombiereloaded>

#if defined _ZombieEscape_INCLUDED
    #endinput
#endif

#define _ZombieEscape_INCLUDED

public SharedPlugin __pl_core = 
{
	name = "ZombieEscape",
	file = "ze_stats.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

enum TYPES
{
	Damage,
	KillHuman,
	KillZombie,
	PassRound,
	Rounds,
	Scores,
	Onlines,
	iShot,
	iHit,
	iHE,
	iPush,
	iFreeze,
	iFire,
	iPoison,
	iCover
}

enum STATS
{
	iRank,
	iFrag,
	iPass,
    iBoss,
	iCash,
	iAuthId,
    iIconRef,
	iDamageRound,
	iDamageCredits,
	iWeaponMenu,
	iWarmDamage,
    iInfectProteection,
    bool:bNextIcon,
	bool:bLoaded,
	bool:bRound,
	bool:bPrint,
	bool:bGiven,
	bool:bOnGround,
	String:szAuthId[32],
	String:szSignature[256],
    String:szHUDName[32],
	String:szAuthName[64],
	String:szPrimary[32],
	String:szSecondary[32],
	Handle:hIntiTimer
}

enum ITEMS
{
	iHENade,
	iFlash,
	iDecoy,
	iSmoke,
	iMolotov,
	iHealth,
	iHArmor,
	iMoney
}

enum NADES
{
    HE,
    Push,
    Freeze,
    Fire,
    Nuke
}

native int ZE_GetPlayerOnlines(int client);
native int ZE_GetPlayerScores(int client);
native int ZE_GetPlayerRank(int client);
native int ZE_GetPlayerPass(int client);
native int ZE_GetPlayerDamage(int client);
native int ZE_GetCommander();
native void ZE_SetCommander(int client);
native bool ZE_StatsEnable();
forward void ZE_OnGameStart();
forward void ZE_OnClientLoaded(int client);
forward int ZE_GetClientGroupStats(int client);