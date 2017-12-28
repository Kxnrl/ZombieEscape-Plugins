//void OnFireMolotov(int entity)
public Action OnFireMolotov(Handle timer, int entity)
{
    if(!IsValidEdict(entity))
        return;
    
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    
    if(!IsValidClient(client))
        return;
    
    Call_StartForward(g_Forward[MOLOTOV]);
    Call_PushCell(client);
    Call_Finish();
}

public void Event_StartBurn(Handle event, const char[] name, bool dontBroadcast)
{
    int entity = GetEventInt(event, "entityid");
    
    if(g_iFireCounts >= 3)
    {
        AcceptEntityInput(entity, "Kill");

        int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
        if(IsValidClient(client))
        {
            PrintToChatAll("[\x0CCG\x01]  已达当前燃烧瓶最大数量");
            //if(IsPlayerAlive(client))
            //    GivePlayerItem(client, "weapon_molotov");
        }

        return;
    }

    g_iFireCounts++;

    float m_fPos[3];
    m_fPos[0] = GetEventFloat(event, "x");
    m_fPos[1] = GetEventFloat(event, "y");
    m_fPos[2] = GetEventFloat(event, "z");
    
    int count = 0;

    for(int client = 1; client <= MaxClients; ++client)
    {
        if(IsClientInGame(client) && IsPlayerAlive(client) && ZR_IsClientZombie(client))
        {
            float org[3];
            GetClientAbsOrigin(client, org);
            if(GetVectorDistance(m_fPos, org) <= 200.0)
                count++;
        }
    }

    if(count >= 15)
    {
        g_iFireCounts--;
        AcceptEntityInput(entity, "Kill");
        PrintToChatAll("[\x0CCG\x01]   请不要往传送点丢火瓶");
    }
    else
    {
        DataPack pack;
        CreateDataTimer(0.5, Timer_FireDelay, pack, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
        WritePackCell(pack, entity);
        WritePackFloat(pack, m_fPos[0]);
        WritePackFloat(pack, m_fPos[1]);
        WritePackFloat(pack, m_fPos[2]);
    }
}

public Action Timer_FireDelay(Handle timer, Handle pack)
{
    ResetPack(pack);
    
    int entity = ReadPackCell(pack);
    
    if(!IsValidEntity(entity))
        return Plugin_Stop;

    float m_fPos[3];
    m_fPos[0] = ReadPackFloat(pack);
    m_fPos[1] = ReadPackFloat(pack);
    m_fPos[2] = ReadPackFloat(pack);

    int count = 0;
    for(int client = 1; client <= MaxClients; ++client)
    {
        if(IsClientInGame(client) && IsPlayerAlive(client) && ZR_IsClientZombie(client))
        {
            float org[3];
            GetClientAbsOrigin(client, org);
            if(GetVectorDistance(m_fPos, org) <= 200.0)
                count++;
        }
    }
    
    if(count >= 15)
    {
        g_iFireCounts--;
        AcceptEntityInput(entity, "Kill");
        PrintToChatAll("[\x0CCG\x01]   请不要往传送点丢火瓶");
        return Plugin_Stop;
    }
    
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    
    if(IsValidClient(client) && IsPlayerAlive(client) && ZR_IsClientZombie(client))
    {
        AcceptEntityInput(entity, "Kill");
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

public void Event_EndBurn(Handle event, const char[] name, bool dontBroadcast)
{
    g_iFireCounts--;
}

/*
void CreateNewInfernoEffect(int client, float m_fPos[3])
{
    g_iFireCounts++;

    int EntityId;
    
    //molotov_groundfire_main
    EntityId = CreateEntityByName("info_particle_system");
    DispatchKeyValue(EntityId, "start_active", "1");
    DispatchKeyValue(EntityId, "effect_name", "molotov_groundfire_main");
    DispatchSpawn(EntityId);
    TeleportEntity(EntityId, m_fPos, NULL_VECTOR,NULL_VECTOR);
    ActivateEntity(EntityId);
    CreateTimer(8.0, Timer_DelectEffect, EntityId, TIMER_FLAG_NO_MAPCHANGE);
    
    //Global
    SetEntPropEnt(EntityId, Prop_Send, "m_hOwnerEntity", client);
    CreateTimer(0.5, Timer_Inferno, EntityId, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

    //molotov_groundfire_00HIGH
    EntityId = CreateEntityByName("info_particle_system");
    DispatchKeyValue(EntityId, "start_active", "1");
    DispatchKeyValue(EntityId, "effect_name", "molotov_groundfire_00HIGH");
    DispatchSpawn(EntityId);
    TeleportEntity(EntityId, m_fPos, NULL_VECTOR,NULL_VECTOR);
    ActivateEntity(EntityId);
    CreateTimer(8.0, Timer_DelectEffect, EntityId, TIMER_FLAG_NO_MAPCHANGE);
    
    //molotov_groundfire_main_center
    EntityId = CreateEntityByName("info_particle_system");
    DispatchKeyValue(EntityId, "start_active", "1");
    DispatchKeyValue(EntityId, "effect_name", "molotov_groundfire_main_center");
    DispatchSpawn(EntityId);
    TeleportEntity(EntityId, m_fPos, NULL_VECTOR,NULL_VECTOR);
    ActivateEntity(EntityId);
    CreateTimer(8.0, Timer_DelectEffect, EntityId, TIMER_FLAG_NO_MAPCHANGE);
    
    //molotov_fire01
    EntityId = CreateEntityByName("info_particle_system");
    DispatchKeyValue(EntityId, "start_active", "1");
    DispatchKeyValue(EntityId, "effect_name", "molotov_fire01");
    DispatchSpawn(EntityId);
    TeleportEntity(EntityId, m_fPos, NULL_VECTOR,NULL_VECTOR);
    ActivateEntity(EntityId);
    CreateTimer(8.0, Timer_DelectEffect, EntityId, TIMER_FLAG_NO_MAPCHANGE);
    
    //molotov_explosion_child_ground1
    EntityId = CreateEntityByName("info_particle_system");
    DispatchKeyValue(EntityId, "start_active", "1");
    DispatchKeyValue(EntityId, "effect_name", "molotov_explosion_child_ground1");
    DispatchSpawn(EntityId);
    TeleportEntity(EntityId, m_fPos, NULL_VECTOR,NULL_VECTOR);
    ActivateEntity(EntityId);
    CreateTimer(0.5, Timer_DelectEffect, EntityId, TIMER_FLAG_NO_MAPCHANGE);
    
    //molotov_explosion_child_ground2
    EntityId = CreateEntityByName("info_particle_system");
    DispatchKeyValue(EntityId, "start_active", "1");
    DispatchKeyValue(EntityId, "effect_name", "molotov_explosion_child_ground2");
    DispatchSpawn(EntityId);
    TeleportEntity(EntityId, m_fPos, NULL_VECTOR,NULL_VECTOR);
    ActivateEntity(EntityId);
    CreateTimer(0.5, Timer_DelectEffect, EntityId, TIMER_FLAG_NO_MAPCHANGE);
    
    for(int target = 1; target <= MaxClients; ++target)
    {
        if(!IsClientInGame(target))
            continue;
        
        if(!IsPlayerAlive(target))
            continue;
        
        if(ZR_IsClientHuman(target))
            continue;
        
        float m_fTargetOrigin[3];
        GetClientAbsOrigin(target, m_fTargetOrigin);
        
        //if(m_fTargetOrigin[2] < m_fPos[2]-70.0 || m_fTargetOrigin[2] > m_fPos[2]+100.0)
        //    continue;
            
        float fDistance = GetVectorDistance(m_fTargetOrigin, m_fPos);
        
        if(fDistance > 200.0)
            continue;

        Handle trace = TR_TraceRayFilterEx(m_fPos, m_fTargetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, target);
    
        if((TR_DidHit(trace) && TR_GetEntityIndex(trace) == target) || (fDistance <= 100.0))
            Grenade_TakeDamage(client, target, 30.0, DMG_BURN, "inferno");
        else
        {
            CloseHandle(trace);
            
            GetClientEyePosition(target, m_fTargetOrigin);

            trace = TR_TraceRayFilterEx(m_fPos, m_fTargetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, target);

            if((TR_DidHit(trace) && TR_GetEntityIndex(trace) == target) || (fDistance <= 100.0))
                Grenade_TakeDamage(client, target, 30.0, DMG_BURN, "inferno");
        }

        CloseHandle(trace);
    }
}

public Action Timer_Inferno(Handle timer, int entity)
{
    if(!IsValidEntity(entity))
    {
        g_iFireCounts--;
        return Plugin_Stop;
    }
    
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    if(!IsValidClient(client))
    {
        g_iFireCounts--;
        AcceptEntityInput(entity, "Kill");
        return Plugin_Stop;
    }

    float m_fPos[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", m_fPos);
    
    int EntityId;
    
    //molotov_explosion_child_ground1
    EntityId = CreateEntityByName("info_particle_system");
    DispatchKeyValue(EntityId, "start_active", "1");
    DispatchKeyValue(EntityId, "effect_name", "molotov_explosion_child_ground1");
    DispatchSpawn(EntityId);
    TeleportEntity(EntityId, m_fPos, NULL_VECTOR,NULL_VECTOR);
    ActivateEntity(EntityId);
    CreateTimer(0.5, Timer_DelectEffect, EntityId, TIMER_FLAG_NO_MAPCHANGE);
    
    //molotov_explosion_child_ground2
    EntityId = CreateEntityByName("info_particle_system");
    DispatchKeyValue(EntityId, "start_active", "1");
    DispatchKeyValue(EntityId, "effect_name", "molotov_explosion_child_ground2");
    DispatchSpawn(EntityId);
    TeleportEntity(EntityId, m_fPos, NULL_VECTOR,NULL_VECTOR);
    ActivateEntity(EntityId);
    CreateTimer(0.5, Timer_DelectEffect, EntityId, TIMER_FLAG_NO_MAPCHANGE);

    for(int target = 1; target <= MaxClients; ++target)
    {
        if(!IsClientInGame(target))
            continue;
        
        if(!IsPlayerAlive(target))
            continue;
        
        if(ZR_IsClientHuman(target))
            continue;
        
        float m_fTargetOrigin[3];
        GetClientAbsOrigin(target, m_fTargetOrigin);
        
        float fDistance = GetVectorDistance(m_fTargetOrigin, m_fPos);
        
        if(fDistance > 200.0)
            continue;

        Handle trace = TR_TraceRayFilterEx(m_fPos, m_fTargetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, target);
    
        if((TR_DidHit(trace) && TR_GetEntityIndex(trace) == target) || (fDistance <= 100.0))
            Grenade_TakeDamage(client, target, 30.0, DMG_BURN, "inferno");
        else
        {
            CloseHandle(trace);
            
            GetClientEyePosition(target, m_fTargetOrigin);

            trace = TR_TraceRayFilterEx(m_fPos, m_fTargetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, target);

            if((TR_DidHit(trace) && TR_GetEntityIndex(trace) == target) || (fDistance <= 100.0))
                Grenade_TakeDamage(client, target, 30.0, DMG_BURN, "inferno");
        }

        CloseHandle(trace);
    }

    return Plugin_Continue;
}*/
/*
void CheckProtectFreezeNade(int client, float origin[3])
{
    Handle pack = CreateDataPack();
    int count, zombie;
    WritePackCell(pack, count);
    
    float targetOrigin[3];
    for(int target = 1; target <= MaxClients; ++target)
    {
        if(!IsClientInGame(target))
            continue;
        
        if(!IsPlayerAlive(target))
            continue;
        
        GetClientAbsOrigin(target, targetOrigin);

        if(GetVectorDistance(origin, targetOrigin) <= g_fDistanceDecoy+100.0)
        {
            if(client == target)
            {
                delete pack;
                return;
            }
            
            if(ZR_IsClientHuman(target))
            {
                count++;
                WritePackCell(pack, GetClientUserId(target));
            }
            else
                zombie++;
        }
    }
    
    if(!zombie || !count)
    {
        delete pack;
        return;
    }
    
    WritePackCell(pack, GetClientUserId(client));
    
    ResetPack(pack);
    WritePackCell(pack, count);

    CreateTimer(g_fDurationDecoy+1.0, Timer_CheckProtect, pack, TIMER_FLAG_NO_MAPCHANGE|TIMER_DATA_HNDL_CLOSE);
}

public Action Timer_CheckProtect(Handle timer, Handle pack)
{
    ResetPack(pack);
    int count = ReadPackCell(pack), left = count;
    for(int x; x < count; ++x)
    {
        int client = GetClientOfUserId(ReadPackCell(pack));
        if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !ZR_IsClientHuman(client))
            left--;
    }
    
    int client = GetClientOfUserId(ReadPackCell(pack));
    
    if(client && IsClientInGame(client) && IsPlayerAlive(client) && ZR_IsClientHuman(client) && left == count)
        Diamonds_ProtectFreezeNade(client, left);
}

void Diamonds_ProtectFreezeNade(int client, int left)
{
    if(GetFeatureStatus(FeatureType_Native, "CG_SetClientDiamond") != FeatureStatus_Available)
        return;
    
    if(GetFeatureStatus(FeatureType_Native, "Store_GetClientCredits") != FeatureStatus_Available)
        return;
    
    if(CG_GetClientUId(client) < 0)
        return;
    
    if(Math_GetRandomInt(0, 100) >= 75)
    {
        CG_SetClientDiamond(client, CG_GetClientDiamond(client)+1);
        PrintToChatAll("[\x10新年快乐\x01]  \x0C%N\x04救命冰冻保护了%d个队友而获得\x0F1钻石", client, left);
    }
    else
    {
        int credits = Math_GetRandomInt(5, 25);
        Store_SetClientCredits(client, Store_GetClientCredits(client)+credits, "ZE-新年活动-救命冰冻");
        PrintToChatAll("[\x10新年快乐\x01]  \x0C%N\x04救命冰冻保护了%d个队友而获得\x0F%d信用点", client, left, credits);
    }
}*/