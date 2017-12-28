//void OnFireNuke(int entity)
public Action OnFireNuke(Handle timer, int entity)
{
    if(!IsValidEdict(entity))
        return;
    
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    
    if(!IsValidClient(client))
        return;
    
    Call_StartForward(g_Forward[NUKE]);
    Call_PushCell(client);
    Call_Finish();
}

public Action CreateEvent_SmokeDetonate(Handle timer, int iReference)
{
    int entity = EntRefToEntIndex(iReference);

    if(entity == INVALID_ENT_REFERENCE)
        return Plugin_Stop;

    if(!IsValidEdict(entity))
        return Plugin_Stop;

    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    
    if(!IsValidClient(client))
        return Plugin_Stop;

    char Classname[64];
    GetEdictClassname(entity, Classname, 64);

    if(StrEqual(Classname, "smokegrenade_projectile"))
    {
        float origin[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
        CreatePoisonSmoke(client, origin);
        AcceptEntityInput(entity, "kill");
    }

    return Plugin_Stop;
}

public Action Event_SmokeDetonate(Handle event, const char[] name, bool dontBroadcast)
{
    SetEventBroadcast(event, true);

    int entity = GetEventInt(event, "entityid");

    if(IsValidEdict(entity))
        AcceptEntityInput(entity, "Kill");

    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    if(!IsValidClient(client))
        return Plugin_Changed;

    float m_fOrigin[3];
    
    m_fOrigin[0] = GetEventFloat(event, "x");
    m_fOrigin[1] = GetEventFloat(event, "y");
    m_fOrigin[2] = GetEventFloat(event, "z");
    
    CreatePoisonSmoke(client, m_fOrigin);

    return Plugin_Changed;
}

public void CreatePoisonSmoke(int client, const float m_fOrigin[3])
{
    if(!IsPlayerAlive(client) || !ZR_IsClientHuman(client))
        return;
    
    char targetname[32];

    // Stack Effects
    int entity = CreateEntityByName("env_smokestack");

    if(entity == -1)
        return;

    Format(targetname, 32, "env_smokestack_%d", entity);
    DispatchKeyValue(entity,"targetname", targetname);
    DispatchKeyValue(entity, "BaseSpread", "100");
    DispatchKeyValue(entity, "SpreadSpeed", "10");
    DispatchKeyValue(entity, "Speed", "80");
    DispatchKeyValue(entity, "StartSize", "200");
    DispatchKeyValue(entity, "EndSize", "2");
    DispatchKeyValue(entity, "Rate", "15");
    DispatchKeyValue(entity, "JetLength", "250");
    DispatchKeyValue(entity, "Twist", "4");
    DispatchKeyValue(entity, "RenderColor", "180 210 0");
    DispatchKeyValue(entity, "RenderAmt", "100");
    DispatchKeyValue(entity, "SmokeMaterial", "particle/particle_smokegrenade1.vmt");
    DispatchSpawn(entity);

    TeleportEntity(entity, m_fOrigin, NULL_VECTOR, NULL_VECTOR);

    AcceptEntityInput(entity, "TurnOn");

    Grenade_KillEntity(g_fDurationSmoke, entity, "env_smokestack", targetname);

    // Emit Sound
    EmitSoundToAll("*maoling/nuke/boom.mp3", entity, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0);

    // Damage Settings
    float dealtime = 0.5;
    float damage = 500.0-(g_iNukeCounts*100.0);

    // Keep timer
    Handle pack;
    CreateDataTimer(dealtime, Timer_SmokeEffect, pack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    WritePackCell(pack, client);
    WritePackCell(pack, entity);
    WritePackFloat(pack, m_fOrigin[0]);
    WritePackFloat(pack, m_fOrigin[1]);
    WritePackFloat(pack, m_fOrigin[2]);
    WritePackFloat(pack, dealtime);
    
    g_iNukeCounts++;

    // Explosion Effects
    if((entity = CreateEntityByName("env_explosion")) != -1)
    {
        SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);
        SetEntProp(entity, Prop_Send, "m_iTeamNum", 3);
        SetEntProp(entity, Prop_Data, "m_spawnflags", 6146);
        SetEntProp(entity, Prop_Data, "m_iMagnitude", RoundToFloor(damage*3.0));
        SetEntProp(entity, Prop_Data, "m_iRadiusOverride", RoundToFloor(g_fDistanceSmoke));
        
        DispatchKeyValue(entity, "classname", "weapon_smokegrenade");

        DispatchSpawn(entity);
        
        ActivateEntity(entity);

        TeleportEntity(entity, m_fOrigin, NULL_VECTOR, NULL_VECTOR);

        AcceptEntityInput(entity, "Explode");
        
        DispatchKeyValue(entity, "classname", "env_explosion");
        
        AcceptEntityInput(entity, "Kill");
    }

    // Light Effects
    if((entity = CreateEntityByName("light_dynamic")) != -1)
    {
        Format(targetname, 32, "light_dynamic_%d", entity);
        DispatchKeyValue(entity,"targetname", targetname);
        DispatchKeyValue(entity, "inner_cone", "0");
        DispatchKeyValue(entity, "cone", "80");
        DispatchKeyValue(entity, "brightness", "5");
        DispatchKeyValue(entity, "spotlight_radius", "96.0");
        DispatchKeyValue(entity, "pitch", "90");
        DispatchKeyValue(entity, "style", "6");
        DispatchKeyValue(entity, "_light", "0 255 0");
        DispatchKeyValueFloat(entity, "distance", 256.0);
        SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

        DispatchSpawn(entity);
        
        TeleportEntity(entity, m_fOrigin, NULL_VECTOR, NULL_VECTOR);
        
        AcceptEntityInput(entity, "TurnOn");

        Grenade_KillEntity(g_fDurationSmoke, entity, "light_dynamic", targetname);
    }

    g_iKills[client] = 0;

    for(int target = 1; target <= MaxClients; ++target)
    {
        if(!IsClientInGame(target))
            continue;
        
        if(!IsPlayerAlive(target))
            continue;
        
        if(!ZR_IsClientZombie(target))
            continue;

        float m_fTargetOrigin[3];
        GetClientAbsOrigin(target, m_fTargetOrigin);

        if(GetVectorDistance(m_fTargetOrigin, m_fOrigin) > g_fDistanceSmoke)
            continue;

        Handle trace = TR_TraceRayFilterEx(m_fOrigin, m_fTargetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, target);
    
        if((TR_DidHit(trace) && TR_GetEntityIndex(trace) == target) || (GetVectorDistance(m_fOrigin, m_fTargetOrigin) <= 100.0))
        {
            NukeToClient(client, target, dealtime, damage);
            CloseHandle(trace);
        }
        else
        {
            CloseHandle(trace);

            GetClientEyePosition(target, m_fTargetOrigin);
            m_fTargetOrigin[2] -= 2.0;

            trace = TR_TraceRayFilterEx(m_fOrigin, m_fTargetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, target);
        
            if((TR_DidHit(trace) && TR_GetEntityIndex(trace) == target) || (GetVectorDistance(m_fOrigin, m_fTargetOrigin) <= 100.0))
                NukeToClient(client, target, dealtime, damage);

            CloseHandle(trace);
        }
    }
}

void NukeToClient(int client, int target, float dealtime, float damage)
{
    RandomAngles(target, dealtime);
    Grenade_TakeDamage(client, target, damage, DMG_POISON, "weapon_smokegrenade");

    if(g_hFreezeTimer[target] != INVALID_HANDLE)
    {
        KillTimer(g_hFreezeTimer[target]);
        SetEntityMoveType(target, MOVETYPE_WALK);
        g_hFreezeTimer[target] = INVALID_HANDLE;
    }
}

public Action Timer_SmokeEffect(Handle timer, Handle pack)
{
    float m_fOrigin[3], dealtime, damage;
    ResetPack(pack);
    int client = ReadPackCell(pack);
    int iEnt = ReadPackCell(pack);
    m_fOrigin[0] = ReadPackFloat(pack);
    m_fOrigin[1] = ReadPackFloat(pack);
    m_fOrigin[2] = ReadPackFloat(pack);
    dealtime = ReadPackFloat(pack);
    damage = 500.0-(g_iNukeCounts*100.0);

    if(!IsValidEdict(iEnt) || !IsClientInGame(client) || !IsPlayerAlive(client) || ZR_IsClientZombie(client))
        return Plugin_Stop;

    if(g_iKills[client] >= 5)
        return Plugin_Stop;

    char szClass[32];
    GetEntityClassname(iEnt, szClass, 32);

    if(!StrEqual(szClass, "env_smokestack"))
        return Plugin_Stop;

    for(int target = 1; target <= MaxClients; ++target)
    {
        if(!IsClientInGame(target))
            continue;
        
        if(!IsPlayerAlive(target))
            continue;
        
        if(!ZR_IsClientZombie(target))
            continue;

        float m_fTargetOrigin[3];
        GetClientAbsOrigin(target, m_fTargetOrigin);

        if(GetVectorDistance(m_fTargetOrigin, m_fOrigin) > g_fDistanceSmoke)
            continue;

        Handle trace = TR_TraceRayFilterEx(m_fOrigin, m_fTargetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, target);
    
        if((TR_DidHit(trace) && TR_GetEntityIndex(trace) == target) || (GetVectorDistance(m_fOrigin, m_fTargetOrigin) <= 100.0))
        {
            NukeToClient(client, target, dealtime, damage);
            CloseHandle(trace);
        }
        else
        {
            CloseHandle(trace);

            GetClientEyePosition(target, m_fTargetOrigin);
            m_fTargetOrigin[2] -= 2.0;

            trace = TR_TraceRayFilterEx(m_fOrigin, m_fTargetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, target);
        
            if((TR_DidHit(trace) && TR_GetEntityIndex(trace) == target) || (GetVectorDistance(m_fOrigin, m_fTargetOrigin) <= 100.0))
                NukeToClient(client, target, dealtime, damage);

            CloseHandle(trace);
        }
    }
    
    return Plugin_Continue;
}

void RandomAngles(int client, float time)
{
    ClearTimer(g_hAnglesTimer[client]);
    g_hAnglesTimer[client] = CreateTimer(time+0.1, Timer_ResetAngles, client);

    float m_fAngles[3];
    GetClientEyeAngles(client, m_fAngles);
    m_fAngles[2] = g_fRandomAngles[GetRandomInt(0,100) % 20];
    TeleportEntity(client, NULL_VECTOR, m_fAngles, NULL_VECTOR);

    int color[4] = {0, 0, 0, 128};
    color[0] = GetRandomInt(0,255);
    color[1] = GetRandomInt(0,255);
    color[2] = GetRandomInt(0,255);

    Handle message = StartMessageOne("Fade", client);
    PbSetInt(message, "duration", 255);
    PbSetInt(message, "hold_time", 255);
    PbSetInt(message, "flags", 0x0002);
    PbSetColor(message, "clr", color);
    EndMessage();
}

public Action Timer_ResetAngles(Handle timer, int client)
{
    g_hAnglesTimer[client] = INVALID_HANDLE;
    
    if(IsClientInGame(client))
    {
        float m_fAngles[3];
        GetClientEyeAngles(client, m_fAngles);
        m_fAngles[2] = 0.0;
        TeleportEntity(client, NULL_VECTOR, m_fAngles, NULL_VECTOR);

        Handle message = StartMessageOne("Fade", client);
        PbSetInt(message, "duration", 1536);
        PbSetInt(message, "hold_time", 1536);
        PbSetInt(message, "flags", (0x0001 | 0x0010));
        PbSetColor(message, "clr", {0, 0, 0, 0});
        EndMessage();
    }
}