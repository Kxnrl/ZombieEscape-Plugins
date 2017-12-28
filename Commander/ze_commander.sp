#include <sdkhooks>
#include <cstrike>
#include <zombiereloaded>
#include <basecomm>
#include <maoling>

#undef REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#include <cg_core>
#include <cg_ze>
#include <voiceannounce_ex>

#pragma newdecls required

#define PLUGIN_PREFIX "[\x0CCG\x01] \x05"

//Vote
bool g_bVoted[MAXPLAYERS+1];
int g_iVoteCount[MAXPLAYERS+1];
Handle g_hVoteMenu;
Handle g_hVoteTimer;

//Commander
int g_iCommander;
int g_iRefIcon;
int g_iRefWall;
bool g_bIsSpeaking;

//Nominate
bool g_bNominated[MAXPLAYERS+1];
bool g_bIsNominate[MAXPLAYERS+1];
bool g_bDown[MAXPLAYERS+1];
bool g_bNomination;

//global
bool g_bGameState;

//others
bool g_bCoreLib;
bool g_bZELib;
bool g_bEvent;

public Plugin myinfo = 
{
    name        = "ZE Commander",
    author      = "Kyle",
    description = "Commander mod for zombiemod reloaded",
    version     = "2.3",
    url         = "https://ump45.moe"
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("CG_ShowGameTextToClient");
    MarkNativeAsOptional("ZE_GetPlayerScores");
    MarkNativeAsOptional("ZE_SetCommander");
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    RegAdminCmd("sm_ckick", AdmCommand_CommanderKick, ADMFLAG_BAN);
    RegAdminCmd("sm_cset", AdmCommand_CommanderSet, ADMFLAG_BAN);

    RegConsoleCmd("sm_cn", Command_Nominate);
    RegConsoleCmd("sm_cwho", Command_Who);
    RegConsoleCmd("sm_chelp", Command_Help);
    RegConsoleCmd("sm_cdown", Command_Down);

    LoadTranslations("kyle/ze.commander.phrases");
}

public void OnPluginEnd()
{
    ClearIcon();
    ClearWallhack();
    OnCommanderDown();
    g_iCommander = 0;
}

public void OnLibraryRemoved(const char[] name)
{
    if(strcmp(name, "csgogamers") == 0)
    {
        g_bCoreLib = false;
        if(!g_bEvent)
        {
            g_bEvent = (
                    HookEventEx("round_start", Event_RoundStart, EventHookMode_Post) ||
                    HookEventEx("round_end", Event_RoundEnd, EventHookMode_Post) ||
                    HookEventEx("player_spawn", Event_PlayerSpawn, EventHookMode_Post) ||
                    HookEventEx("player_death", Event_PlayerDeath, EventHookMode_Post)
                    )
        }
    }
    else if(strcmp(name, "ZombieEscape") == 0)
    {
        g_bZELib = false;
    }
}

public void OnMapStart()
{
    //Head icon
    AddFileToDownloadsTable("materials/maoling/sprites/ze/commander_wh.vmt");
    AddFileToDownloadsTable("materials/maoling/sprites/ze/commander_wh.vtf");
    PrecacheModel("materials/maoling/sprites/ze/commander_wh.vmt");

    //Reset
    ResetCommander();
    ResetVote();
    VoteMenuClose();
    VoteTimerClose();
    
    //Global
    g_bGameState = false;
    
    //Ref
    g_iRefIcon = INVALID_ENT_REFERENCE;
    g_iRefWall = INVALID_ENT_REFERENCE;
    
    CreateTimer(5.0, Timer_RefreshHUD, _, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);
    
    //Others
    g_bCoreLib = LibraryExists("csgogamers");
    g_bZELib = LibraryExists("ZombieEscape");

    if(!g_bCoreLib && !g_bEvent)
    {
        g_bEvent = (
                    HookEventEx("round_start", Event_RoundStart, EventHookMode_Post) ||
                    HookEventEx("round_end", Event_RoundEnd, EventHookMode_Post) ||
                    HookEventEx("player_spawn", Event_PlayerSpawn, EventHookMode_Post) ||
                    HookEventEx("player_death", Event_PlayerDeath, EventHookMode_Post)
                    )
    }
}

public Action Timer_RefreshHUD(Handle timer)
{
    char szGameText[128];
    
    for(int client = 1; client <= MaxClients; ++client)
    {
        if(!IsClientInGame(client))
            continue;
        
        if(g_hVoteTimer != INVALID_HANDLE)
            FormatEx(szGameText, 256, "%T: %T", "current commander", client, "waiting", client);
        else if(g_hVoteMenu != INVALID_HANDLE)
            FormatEx(szGameText, 256, "%T: %T", "current commander", client, "voting", client);
        else if(IsAliveCommander())
            FormatEx(szGameText, 256, "%T: %N", "current commander", client, g_iCommander);
        else
            FormatEx(szGameText, 256, "%T: null", "current commander", client);
        
        UTIL_ShowTextToClient(client, szGameText);
    }

    return Plugin_Continue;
}

void UTIL_ShowTextToClient(int client, const char[] msg)
{
    if(g_bCoreLib)
    {
        CG_ShowGameTextToClient(msg, "5.0", "9 255 9", "0.150625", "0.010000", client);
        return;
    }

    static Handle g_hSyncHUD;
    if(g_hSyncHUD == INVALID_HANDLE)
        g_hSyncHUD = CreateHudSynchronizer();
    
    SetHudTextParams(0.150625, 0.010000, 5.0, 9, 255, 9, 255, 0, 10.0, 5.0, 5.0);
    ShowSyncHudText(client, g_hSyncHUD, msg);
}

public void ZE_OnGameStart()
{
    g_bGameState = true;
    
    if(!FindPluginByFile("ze_marker.smx"))
        ServerCommand("sm plugins load ze_marker.smx");
}

public void OnMapEnd()
{
    g_hVoteMenu = INVALID_HANDLE;
    g_hVoteTimer = INVALID_HANDLE;

    if(g_bEvent)
    {
        UnhookEvent("round_start", Event_RoundStart, EventHookMode_Post);
        UnhookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
        UnhookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
        UnhookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    }
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    CG_OnRoundStart();
}

public void CG_OnRoundStart()
{
    ClearIcon();
    ClearWallhack();

    if(!g_iCommander)
    {
        ResetVote();
        VoteMenuClose();
        VoteTimerClose();
        NominateClear();

        g_hVoteTimer = CreateTimer(30.0, Timer_StartVote, _, TIMER_FLAG_NO_MAPCHANGE);

        tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "commander vote countdown");
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    CG_OnRoundEnd(GetEventInt(event, "winner"));
}

public void CG_OnRoundEnd(int winner)
{    
    SurvivedCheck();
    OnCommanderDown();
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    CG_OnClientSpawn(GetClientOfUserId(GetEventInt(event, "userid")));
}

public void CG_OnClientSpawn(int client)
{
    if(client != g_iCommander)
        return;

    OnCommanderSet(g_iCommander);
    CreateTimer(2.0, Timer_CommanderSpawn);
}

public Action Timer_CommanderSpawn(Handle timer)
{
    if(!IsAliveCommander())
    {
        OnCommanderDown();
        return Plugin_Stop;
    }

    OnCommanderSet(g_iCommander);
    CreateIcon();
    CreateWallhack();

    return Plugin_Stop;
}
 
public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(GetEventInt(event, "userid"));
    int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    int assister = GetClientOfUserId(GetEventInt(event, "assister"));
    bool headshot = GetEventBool(event, "headshot");
    char weapon[32];
    GetEventString(event, "weapon", weapon, 32, "");

    CG_OnClientDeath(victim, attacker, assister, headshot, weapon);
}

public void CG_OnClientDeath(int client, int attacker, int assister, bool headshot, const char[] weapon)
{
    if(client != g_iCommander || attacker != 0)
        return;

    OnCommanderDown();
    ClearIcon();
    ClearWallhack();
    CommanderDown(2);
}

public void OnClientDisconnect(int client)
{
    g_bDown[client] = false;

    if(client != g_iCommander)
        return;

    ResetCommander();
    ResetVote();
    VoteMenuClose();
    VoteTimerClose();

    g_hVoteTimer = CreateTimer(30.0, Timer_StartVote, _, TIMER_FLAG_NO_MAPCHANGE);

    tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "commander disconnected");
    tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "commander vote countdown");
}

public Action AdmCommand_CommanderKick(int client, int args)
{
    ResetCommander();
    ResetVote();
    VoteMenuClose();
    VoteTimerClose();

    g_hVoteTimer = CreateTimer(30.0, Timer_StartVote, _, TIMER_FLAG_NO_MAPCHANGE);

    tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "commander kick");
    tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "commander vote countdown");
    
    return Plugin_Handled;
}

public Action AdmCommand_CommanderSet(int client, int args)
{
    if(!client)
        return Plugin_Handled;
    
    Handle menu = CreateMenu(MenuHandlerSetCommander);
    SetMenuTitle(menu, "[CG]  选择要设置的指挥官");

    int iCount;
    for(int i = 1; i <= MaxClients; ++i)
    {
        if(!IsClientInGame(i))
            continue;

        char name[128];
        Format(name, 128, "%N [%d score]", i, GetSocres(i));
        
        char uid[8];
        Format(uid, 8, "%d", GetClientUserId(i));

        AddMenuItem(menu, uid, name);
        iCount++;
    }
    
    if(GetMenuItemCount(menu) >= 1)
        DisplayMenu(menu, client, 20);
    else
        CloseHandle(menu);

    return Plugin_Handled;
}

int GetSocres(int client)
{
    return g_bZELib ? ZE_GetPlayerScores(client) : CS_GetClientContributionScore(client);
}

public int MenuHandlerSetCommander(Handle menu, MenuAction action, int client, int param2)
{
    if(action == MenuAction_Select)
    {
        char info[16];
        GetMenuItem(menu, param2, info, 16);
        int target = GetClientOfUserId(StringToInt(info));
        if(IsValidClient(target))
        {
            ResetCommander();
            ResetVote();
            VoteMenuClose();
            VoteTimerClose();

            tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "admin set commander", target);
            NominateClear();

            NewCommander(target);
        }
    }
    else if(action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

public Action Command_Nominate(int client, int args)
{
    if(g_iCommander)
    {
        tPrintToChat(client, "%s  %t", PLUGIN_PREFIX, "cant nominate by commander", g_iCommander);
        return Plugin_Handled;
    }

    if(g_bNominated[client])
    {
        tPrintToChat(client, "%s  %t", PLUGIN_PREFIX, "cant nominate by nominated");
        return Plugin_Handled;
    }

    int iCount = 0;
    float fScores[MAXPLAYERS+1][2];
    
    for(int i = 1; i <= MaxClients; ++i)
    {
        if(!IsClientInGame(i))
            continue;

        fScores[iCount][0] = float(i); 
        fScores[iCount][1] = float(GetSocres(i));
        iCount++;
    }

    SortCustom2D(view_as<int>(fScores), MAXPLAYERS+1, SortScoreDesc_f);
    
    Handle menu = CreateMenu(MenuHandlerNominate);
    SetMenuTitleEx(menu, "%T", "commander nomination title", client);
    
    iCount = 0;
    int target;

    for(int i = 1; i <= MaxClients; i++)
    {
        target = RoundToFloor(fScores[iCount][0]);
        
        if(target == 0 || GetUID(client) <= 0 || !IsPlayerAlive(client))
        {
            iCount++;
            continue;
        }

        char name[128];
        Format(name, 128, "%N [%d Score]", target, GetSocres(target));
        
        char uid[8];
        Format(uid, 8, "%d", GetClientUserId(target));
        AddMenuItem(menu, uid, name);
        iCount++;
    }

    SetMenuExitButton(menu, true);

    if(GetMenuItemCount(menu) >= 1)
        DisplayMenu(menu, client, 20);
    else
        CloseHandle(menu);

    return Plugin_Handled;
}

int GetUID(int client)
{
    return g_bCoreLib ? CG_ClientGetUId(client) : 1;
}

public int MenuHandlerNominate(Handle menu, MenuAction action, int client, int param2)
{
    if(action == MenuAction_Select)
    {
        char info[100];
        GetMenuItem(menu, param2, info, 100);
        int target = GetClientOfUserId(StringToInt(info));
        if(IsValidClient(target))
        {
            g_bIsNominate[target] = true;
            g_bNominated[client] = true;
            g_bNomination = true;
            tPrintToChat(client, "%s  Nominated %N", PLUGIN_PREFIX, target);
        }
    }
    if(action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

public Action Command_Who(int client, int args)
{
    if(!client)
        return Plugin_Handled;

    if(!g_iCommander)
        tPrintToChat(client, "%s  %t", PLUGIN_PREFIX, "no commander");
    else
        tPrintToChat(client, "%s  %t", PLUGIN_PREFIX, "show commander", g_iCommander, GetSocres(g_iCommander));

    return Plugin_Handled;
}

public Action Command_Help(int client, int args)
{
    if(!client)
        return Plugin_Handled;
    
    HelpPanel(client);
    
    return Plugin_Handled;
}

public Action Command_Down(int client, int args)
{
    if(client != g_iCommander)
        return Plugin_Handled;

    ResetCommander();
    ResetVote();
    VoteMenuClose();
    VoteTimerClose();
    
    g_bDown[client] = true;
    
    g_hVoteTimer = CreateTimer(30.0, Timer_StartVote, _, TIMER_FLAG_NO_MAPCHANGE);
    
    tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "commander resigned");
    tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "commander vote countdown");
    
    return Plugin_Handled;
}

void HelpPanel(int client)
{
    Handle panel = CreatePanel(GetMenuStyleHandle(MenuStyle_Radio));
    DrawPanelText(panel,"[指挥官系统] 指令: !cn !ctop !cwho");
    DrawPanelText(panel,"Chinese:");
    DrawPanelText(panel,"- 使用武器特殊功能键来放置标志.");
    DrawPanelText(panel,"- 按住按键移动鼠标来设置范围.");
    DrawPanelText(panel,"- 当你里标志很远,他会消失.");
    DrawPanelText(panel,"- 每存活一局你都将获得一定点数.");
    DrawPanelText(panel,"- 指挥官不会成为母体僵尸 ;).");
    DrawPanelText(panel,"English:");
    DrawPanelText(panel,"- Use Rightclick/Zoom to set Markers.");
    DrawPanelText(panel,"- Hold the button to increase the diameter.");
    DrawPanelText(panel,"- Markers will be pruned, when you to far away.");
    DrawPanelText(panel,"- Get Points for every Surviver.");
    DrawPanelText(panel,"- The Commander does not spawn as Zombie, EVER.");
    DrawPanelItem(panel," ",ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
    DrawPanelItem(panel,"Exit");
    SendPanelToClient(panel,client,PH,30);
    CloseHandle(panel);
}

public int PH(Handle menu, MenuAction action, int p1, int p2)
{
    if(action == MenuAction_End)
    {
        CloseHandle(menu);
    }
}

void SurvivedCheck()
{
    if(IsAliveCommander())
        tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "commander survived");
}

void CommanderDown(int type)
{
    if(type == 1)
        tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "commander infected");
    else if(type == 2) 
        tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "commander down");

    g_bIsSpeaking = false;
}

void ResetCommander()
{
    if(g_iCommander)
    {
        OnCommanderDown();
        tPrintToChat(g_iCommander, "%s  %t", PLUGIN_PREFIX, "uncommander");
    }

    ClearIcon();
    ClearWallhack();
    g_iCommander = 0;
    g_bIsSpeaking = false;
}

bool NewCommander(int client)
{
    if(g_iCommander && g_iCommander != client && IsClientInGame(g_iCommander))
        tPrintToChat(g_iCommander, "%s  %t", PLUGIN_PREFIX, "uncommander");

    g_iCommander = client;
    
    tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "show commander", g_iCommander, GetSocres(g_iCommander));
    
    if(IsPlayerAlive(g_iCommander) && ZR_IsClientZombie(g_iCommander))
    {
        tPrintToChatAll("%s  %t", PLUGIN_PREFIX, "commander is zombie");
        return;
    }

    ClearIcon();
    ClearWallhack();

    CreateIcon();
    CreateWallhack();

    OnCommanderSet(client);
}

void CreateWallhack()
{
    g_iRefWall = INVALID_ENT_REFERENCE;

    int entity = CreatePlayerModelProp();
    
    static int offset;

    if(!offset && (offset = GetEntSendPropOffs(entity, "m_clrGlow")) == -1)
    {
        LogError("Unable to find property offset: \"m_clrGlow\"!");
        return;
    }

    SetEntProp(entity, Prop_Send, "m_bShouldGlow", true, true);
    SetEntProp(entity, Prop_Send, "m_nGlowStyle", 0);
    SetEntPropFloat(entity, Prop_Send, "m_flGlowMaxDist", 100000.0);

    SetEntData(entity, offset, 0, _, true);
    SetEntData(entity, offset + 1, 255, _, true);
    SetEntData(entity, offset + 2, 0, _, true);
    SetEntData(entity, offset + 3, 255, _, true);

    SDKHook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
}

#define EF_BONEMERGE                (1 << 0)
#define EF_NOSHADOW                 (1 << 4)
#define EF_NORECEIVESHADOW          (1 << 6)
#define EF_PARENT_ANIMATES          (1 << 9)

int CreatePlayerModelProp()
{
    ClearWallhack();
    char sModel[128], sFmt[32];
    GetClientModel(g_iCommander, sModel, 128);
    int Ent = CreateEntityByName("prop_dynamic_override");
    FormatEx(sFmt, 32, "commander_waller_%d", Ent);
    DispatchKeyValue(Ent,"targetname", sFmt);
    DispatchKeyValue(Ent, "model", sModel);
    DispatchKeyValue(Ent, "disablereceiveshadows", "1");
    DispatchKeyValue(Ent, "disableshadows", "1");
    DispatchKeyValue(Ent, "solid", "0");
    DispatchKeyValue(Ent, "spawnflags", "256");
    SetEntProp(Ent, Prop_Send, "m_CollisionGroup", 11);
    DispatchSpawn(Ent);
    SetEntProp(Ent, Prop_Send, "m_fEffects", EF_BONEMERGE|EF_NOSHADOW|EF_NORECEIVESHADOW|EF_PARENT_ANIMATES);
    SetVariantString("!activator");
    AcceptEntityInput(Ent, "SetParent", g_iCommander, Ent, 0);
    SetVariantString("primary");
    AcceptEntityInput(Ent, "SetParentAttachment", Ent, Ent, 0);

    g_iRefWall = EntIndexToEntRef(Ent);

    return Ent;
}

void ClearWallhack()
{
    int entity;
    if(g_iRefWall != INVALID_ENT_REFERENCE && IsValidEdict((entity = EntRefToEntIndex(g_iRefWall))))
    {
        char szClass[32];
        GetEntityClassname(entity, szClass, 32);        
        if(StrEqual(szClass, "prop_dynamic"))
        {
            char m_szName[32];
            GetEntPropString(entity, Prop_Data, "m_iName", m_szName, 32);
            if(StrContains(m_szName, "commander_waller_", false) == 0)
            {
                SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit);
                AcceptEntityInput(entity, "Kill");
            }
        }
    }

    g_iRefWall = INVALID_ENT_REFERENCE;
}

void CreateIcon()
{
    float fOrigin[3];
    GetClientAbsOrigin(g_iCommander, fOrigin);                
    fOrigin[2] = fOrigin[2] + 93.5;

    int iEnt = CreateEntityByName("env_sprite");
    
    DispatchKeyValue(iEnt, "model", "materials/maoling/sprites/ze/commander_wh.vmt");
    DispatchKeyValue(iEnt, "classname", "env_sprite");
    DispatchKeyValue(iEnt, "spawnflags", "1");
    DispatchKeyValue(iEnt, "scale", "0.08");
    DispatchKeyValue(iEnt, "rendermode", "1");
    DispatchKeyValue(iEnt, "rendercolor", "255 255 255");
    DispatchSpawn(iEnt);
    TeleportEntity(iEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
    SetVariantString("!activator");
    AcceptEntityInput(iEnt, "SetParent", g_iCommander, iEnt, 0);

    SDKHook(iEnt, SDKHook_SetTransmit, Hook_SetTransmit);

    g_iRefIcon = EntIndexToEntRef(iEnt);
}

void ClearIcon()
{
    if(g_iRefIcon != INVALID_ENT_REFERENCE)
    {
        int iEnt = EntRefToEntIndex(g_iRefIcon);
        if(IsValidEdict(iEnt))
        {
            char szClass[32];
            GetEntityClassname(iEnt, szClass, 32);
            if(StrEqual(szClass, "env_sprite"))
            {
                AcceptEntityInput(iEnt, "Kill");
                SDKUnhook(iEnt, SDKHook_SetTransmit, Hook_SetTransmit);
            }
        }
    }

    g_iRefIcon = INVALID_ENT_REFERENCE;
}

public Action Hook_SetTransmit(int entity, int client)
{
    if(client == g_iCommander)
        return Plugin_Handled;
    
    if(!IsPlayerAlive(client))
        return Plugin_Handled;
    
    if(ZR_IsClientZombie(client))
        return Plugin_Handled;

    return Plugin_Continue;
}

void ResetVote()
{
    for(int client = 1; client <= MaxClients; client++)
        g_bVoted[client] = false;
}

public Action Timer_StartVote(Handle timer)
{
    g_hVoteTimer = INVALID_HANDLE;
    
    if(!g_bGameState)
        return Plugin_Stop;

    if(!IsVoteInProgress(g_hVoteMenu))
        StartVote();

    return Plugin_Stop;
}

bool StartVote()
{
    VoteMenuClose();
    VoteTimerClose();
    
    for(int i = 1; i <= MAXPLAYERS; ++i) 
        g_iVoteCount[i] = 0;
    
    int iCount = 0;
    float fScores[MAXPLAYERS+1][2];
    
    for(int i = 1; i <= MaxClients; ++i)
    {
        if(!IsClientInGame(i))
            continue;

        if(g_bNomination && !g_bIsNominate[i])
            continue;

        if(g_bDown[i] && !g_bIsNominate[i])
            continue;

        if(GetSocres(i) <= 800 || GetUID(i) <= 0 || !IsPlayerAlive(i))
            continue;

        fScores[iCount][0] = float(i); 
        fScores[iCount][1] = float(GetSocres(i));
        iCount++;
    }

    SortCustom2D(view_as<int>(fScores), MAXPLAYERS+1, SortScoreDesc_f);
    
    g_hVoteMenu = CreateMenu(Handle_VoteMenu, view_as<MenuAction>(MENU_ACTIONS_ALL));
    
    SetMenuTitleEx(g_hVoteMenu, "%t", "vote commander title");
    
    iCount = 0;
    int target, nCount;
    
    for(int i = 0;i <= MaxClients; ++i)
    {
        target = RoundToFloor(fScores[iCount][0]);
        
        if(target == 0)
        {
            iCount++;
            continue;
        }
        
        iCount++;

        char name[128];
        Format(name, 128, "%N [%d Score]", target, GetSocres(target));
        
        char uid[8];
        Format(uid, 8, "%d", GetClientUserId(target));
        AddMenuItem(g_hVoteMenu, uid, name);
        
        nCount++;
    }
    
    if(nCount > 1)
    {
        SetMenuExitButton(g_hVoteMenu, false);
        VoteMenuToAll(g_hVoteMenu, 20);
    }
    else
    {
        VoteMenuClose();
        VoteTimerClose();
    }
    
    NominateClear();

    return true;    
}

public int Handle_VoteMenu(Handle menu, MenuAction action, int param1, int param2)
{
    if (action == MenuAction_End)
    {
        CloseHandle(menu);
        g_hVoteMenu = INVALID_HANDLE;
    }
    else if (action == MenuAction_Select)
    {
        char info[100];
        GetMenuItem(menu, param2, info, 100);
        int target = GetClientOfUserId(StringToInt(info));
        if(1<= target <= MaxClients && IsClientInGame(target))
        {
            g_iVoteCount[target]++;
        }
    }
    else if(action == MenuAction_VoteEnd)
    {
        EndVote();
        g_hVoteMenu = INVALID_HANDLE;
    }
}

bool EndVote()
{
    int winner = 0;
    int winner_votes = 0;
    
    for(int client = 1; client <= MaxClients; ++client)
    {
        if(!IsClientInGame(client))
            continue;
        
        if(g_iVoteCount[client] > winner_votes)
        {
            winner_votes = g_iVoteCount[client];
            winner = client;
        }
    }
    
    if(winner)
    {
        NewCommander(winner);
        return true;
    }

    return false;
}

void VoteMenuClose()
{
    if(g_hVoteMenu != INVALID_HANDLE)
        CloseHandle(g_hVoteMenu);

    g_hVoteMenu = INVALID_HANDLE;
}

void VoteTimerClose()
{
    ClearTimer(g_hVoteTimer);
}

void NominateClear()
{
    g_bNomination = false;
    for(int client = 1; client <= MaxClients; ++client)
    {
        g_bIsNominate[client] = false;
        g_bNominated[client] = false;
    }
}

public int ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
    if(client == g_iCommander)
    {
        ClearIcon();
        ClearWallhack();
        CommanderDown(1);
        OnCommanderDown();
        g_bIsSpeaking = false;
    }
}

public int SortScoreDesc_f(int[] x, int[] y, int[][] array, Handle data)
{
    if(view_as<float>(x[1]) > view_as<float>(y[1]))
        return -1;
    
    return view_as<float>(x[1]) < view_as<float>(y[1]);
}

//Voice Hook  指挥官开麦让小朋友闭嘴功能
public int OnClientSpeakingEx(int client)
{
    if(!g_bIsSpeaking && client == g_iCommander && IsAliveCommander())
    {
        g_bIsSpeaking = true;
        for(int i = 1; i <= MaxClients; i++)
            if(IsClientInGame(i) && i != client)
                SetClientListeningFlags(i, VOICE_MUTED);
    }
}

public int OnClientSpeakingEnd(int client)
{
    if(client == g_iCommander)
    {
        g_bIsSpeaking = false;
        for(int i = 1; i <= MaxClients; i++)
            if(IsClientInGame(i))
                if(!BaseComm_IsClientMuted(i))
                    SetClientListeningFlags(i, VOICE_NORMAL);
    }
}

void OnCommanderSet(int client)
{
    ZE_SetCommander(client);
    g_bIsSpeaking = false;
    CreateTimer(0.0, Timer_RefreshHUD);
}

void OnCommanderDown()
{
    ZE_SetCommander(0);
    g_bIsSpeaking = false;
    CreateTimer(0.0, Timer_RefreshHUD);
}

stock bool IsAliveCommander()
{
    if(!IsValidClient(g_iCommander))
        return false;
    
    if(!IsPlayerAlive(g_iCommander))
        return false;
    
    if(!ZR_IsClientHuman(g_iCommander))
        return false;

    return true;
}