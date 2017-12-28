#include <sdkhooks>
#include <zombiereloaded>
#include <zr_tools>
#include <maoling>

#pragma newdecls required

#define FreezeColor             {255, 0, 0, 75}
#define redColor                {127, 0, 255, 70}
#define SOUND_FREEZE            "physics/glass/glass_impact_bullet4.wav"
#define SOUND_FREEZE_EXPLODE    "ui/freeze_cam.wav"

#define HEGRENADE   0
#define FREEZE      1
#define MOLOTOV     2
#define PUSH        3
#define NUKE        4

int g_iBeamSprite;
int g_iHaloSprite;
int g_iGlowSprite;
int g_iNukeCounts;
int g_iFireCounts;

int g_iKills[MAXPLAYERS+1];

float g_fRandomAngles[20] = {0.0, 5.0, 10.0, 15.0, 20.0, 25.0, 20.0, 15.0, 10.0, 5.0, 0.0, -5.0, -10.0, -15.0, -20.0, -25.0, -20.0, -15.0, -10.0, -5.0};
float g_fDistanceFlash;
float g_fDurationFlash;
float g_fDistanceDecoy;
float g_fDurationDecoy;
float g_fDistanceSmoke;
float g_fDurationSmoke;

Handle CVAR_DISTANCE_FLASH;
Handle CVAR_DURATION_FLASH;
Handle CVAR_DISTANCE_DECOY;
Handle CVAR_DURATION_DECOY;
Handle CVAR_DISTANCE_SMOKE;
Handle CVAR_DURATION_SMOKE;

Handle g_hFreezeTimer[MAXPLAYERS+1];
Handle g_hAnglesTimer[MAXPLAYERS+1];

Handle g_Forward[5];

ArrayList array_timer;

#include "nade/cvar.sp"
#include "nade/hegrenade.sp"
#include "nade/fire.sp"
#include "nade/freeze.sp"
#include "nade/push.sp"
#include "nade/nuke.sp"
//#include "nade/hole.sp"

public Plugin myinfo = 
{
    name        = "ZE Grenade",
    author      = "Kyle",
    description = "",
    version     = "1.5b",
    url         = "https://ump45.moe"
}

public void OnPluginStart()
{
    //HookEvent("tagrenade_detonate", Event_TagrenadeDetonate, EventHookMode_Post);
    HookEvent("smokegrenade_detonate", Event_SmokeDetonate, EventHookMode_Pre);
    HookEvent("inferno_startburn", Event_StartBurn, EventHookMode_Post);
    HookEvent("inferno_expire", Event_EndBurn, EventHookMode_Post);
    
    HookEvent("round_start", Event_RoundStart, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post)

    ConVar_OnPluginStart();

    g_Forward[HEGRENADE] = CreateGlobalForward("ZE_OnClientFireHEPost", ET_Event, Param_Cell);
    g_Forward[FREEZE] = CreateGlobalForward("ZE_OnClientFireFreezePost", ET_Event, Param_Cell);
    g_Forward[MOLOTOV] = CreateGlobalForward("ZE_OnClientFireMolotovPost", ET_Event, Param_Cell);
    g_Forward[PUSH] = CreateGlobalForward("ZE_OnClientFirePushPost", ET_Event, Param_Cell);
    g_Forward[NUKE] = CreateGlobalForward("ZE_OnClientFireNukePost", ET_Event, Param_Cell);

    array_timer = CreateArray();

    AutoExecConfig(true, "kyle/ZombieEscape.Grenade");

    RegAdminCmd("sm_t", Command_T, ADMFLAG_ROOT);
}

public Action Command_T(int client, int args)
{
    GivePlayerItem(client, "weapon_tagrenade");
}

public void OnMapStart() 
{
    g_iGlowSprite = PrecacheModel("materials/sprites/blueglow1.vmt");
    g_iBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
    g_iHaloSprite = PrecacheModel("materials/sprites/halo.vmt");

    PrecacheSound(SOUND_FREEZE);
    PrecacheSound(SOUND_FREEZE_EXPLODE);

    g_iFireCounts = 0;
    g_iNukeCounts = 0;
    
    ClearArray(array_timer);
    
    //AddFileToDownloadsTable("particles/futuristicgrenades/futuristicgrenades.pcf");
    //PrecacheGeneric("particles/futuristicgrenades/futuristicgrenades.pcf", true);
}

public void OnClientDisconnect(int client)
{
    ClearTimer(g_hFreezeTimer[client]);
    ClearTimer(g_hAnglesTimer[client]);
}

public void OnEntityCreated(int entity, const char[] classname)
{
    if(StrContains(classname, "_projectile") > 0)
        SDKHook(entity, SDKHook_SpawnPost, Grenades_OnEntitySpawnedPost);
}

public Action Timer_OnGrenadeCreated(Handle timer, int iReference)
{
    int entity = EntRefToEntIndex(iReference);
    if(entity != INVALID_ENT_REFERENCE)
        SetEntProp(entity, Prop_Data, "m_nNextThinkTick", -1);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_iNukeCounts = 0;
    g_iFireCounts = 0;
    
    while(GetArraySize(array_timer))
    {
        Handle timer = GetArrayCell(array_timer, 0);
        KillTimer(timer);
        RemoveFromArray(array_timer, 0);
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

    g_iKills[attacker]++;
    ClearTimer(g_hFreezeTimer[victim]);
    //ClearTimer(g_hAnglesTimer[victim]);
}

public void Grenade_KillEntity(float delay, int entity, const char[] classname, const char[] targetname)
{
    Handle pack;
    Handle timer = CreateDataTimer(delay, Timer_KillEntity, pack, TIMER_FLAG_NO_MAPCHANGE);
    WritePackCell(pack, EntIndexToEntRef(entity));
    WritePackString(pack, classname);
    WritePackString(pack, targetname);
    WritePackCell(pack, timer);
    ResetPack(pack);
    PushArrayCell(array_timer, timer);
}

public Action Timer_KillEntity(Handle timer, Handle pack)
{
    int idx = FindValueInArray(array_timer, timer);
    if(idx != -1)
        RemoveFromArray(array_timer, idx);
    else
        PrintToChatAll("Not Found In Array");
    
    int entity = EntRefToEntIndex(ReadPackCell(pack));
    char classname[32], targetname[32];
    ReadPackString(pack, classname, 32);
    ReadPackString(pack, targetname, 32);
    
    if(!IsValidEntity(entity))
        return Plugin_Stop;
    
    char entityclass[32];
    GetEntityClassname(entity, entityclass, 32);
    
    if(!StrEqual(entityclass, classname))
        return Plugin_Stop;
    
    char entityname[32];
    GetEntPropString(entity, Prop_Data, "m_iName", entityname, 32);
    if(!StrEqual(entityname, targetname))
        return Plugin_Stop;
        
    AcceptEntityInput(entity, "Kill");
    
    return Plugin_Stop;
}

void Grenade_TakeDamage(int attacker, int victim, float damage, int DMG_TYPE = DMG_POISON, const char[] sWeapon = "")
{
    int iEnt = CreateEntityByName("point_hurt");
    
    if(iEnt == -1)
        return;
    
    char oldName[128];
    GetEntPropString(victim, Prop_Data, "m_iName", oldName, 128);  

    char sDamage[16];
    FloatToString(damage, sDamage, 16);

    char sDamageType[32];
    IntToString(DMG_TYPE, sDamageType, 32);

    DispatchKeyValue(victim, "targetname", "war3_hurtme");

    DispatchKeyValue(iEnt, "DamageTarget", "war3_hurtme");
    DispatchKeyValue(iEnt, "Damage", sDamage);
    DispatchKeyValue(iEnt, "DamageType", sDamageType);
    DispatchKeyValue(iEnt, "classname", sWeapon);

    DispatchSpawn(iEnt);

    AcceptEntityInput(iEnt,    "Hurt", attacker);

    DispatchKeyValue(iEnt, "classname", "point_hurt");
    
    //Prevent some maps clear client`s score...
    DispatchKeyValue(victim, "targetname", oldName);
    AcceptEntityInput(iEnt, "Kill");
}

public bool FilterTarget(int entity, int contentsMask, any data)
{
    return (data == entity);
}

public void Grenades_OnEntitySpawnedPost(int entity)
{
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    
    if(!(0 < client <= MaxClients))
        return;
    
    char classname[32];
    GetEdictClassname(entity, classname, 32);
    
    if(StrEqual(classname, "hegrenade_projectile"))
    {
        CreateTimer(0.0, OnFireHE, entity);
    }
    else if(StrEqual(classname, "molotov_projectile"))
    {
        CreateTimer(0.0, OnFireMolotov, entity);
    }
    else if(StrEqual(classname, "decoy_projectile"))
    {
        int iReference = EntIndexToEntRef(entity);
        CreateTimer(1.3, CreateEvent_DecoyDetonate, iReference, TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(0.0, Timer_OnGrenadeCreated, iReference);
        CreateTimer(0.0, OnFireFreeze, entity);
    }
    else if(StrEqual(classname, "flashbang_projectile"))
    {
        int iReference = EntIndexToEntRef(entity);
        CreateTimer(1.3, CreateEvent_FlashDetonate, iReference, TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(0.0, Timer_OnGrenadeCreated, iReference);
        CreateTimer(0.0, OnFirePush, entity);
    }
    else if(StrEqual(classname, "smokegrenade_projectile"))
    {
        int iReference = EntIndexToEntRef(entity);
        CreateTimer(1.3, CreateEvent_SmokeDetonate, iReference, TIMER_FLAG_NO_MAPCHANGE);
        CreateTimer(0.0, Timer_OnGrenadeCreated, iReference);
        CreateTimer(0.0, OnFireNuke, entity);
    }
}