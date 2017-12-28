//void OnFirePush(int entity)
public Action OnFirePush(Handle timer, int entity)
{
    if(!IsValidEdict(entity))
        return;
    
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    
    if(!IsValidClient(client))
        return;
    
    Call_StartForward(g_Forward[PUSH]);
    Call_PushCell(client);
    Call_Finish();
}

public Action CreateEvent_FlashDetonate(Handle timer, int iReference)
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

    if(StrEqual(Classname, "flashbang_projectile"))
    {
        float origin[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
        Flash_Effects(client, origin);
        AcceptEntityInput(entity, "kill");
    }

    return Plugin_Stop;
}

void Flash_Effects(int client, float origin[3])
{
    origin[2] += 10.0;
    TE_SetupBeamRingPoint(origin, 10.0, g_fDistanceFlash, g_iBeamSprite, g_iHaloSprite, 1, 1, 0.2, 100.0, 1.0, FreezeColor, 0, 0);
    TE_SendToAll();
    Flash_LightCreate(client, origin);
}

void Flash_LightCreate(int client, float pos[3])   
{  
    int entity = CreateEntityByName("light_dynamic");
    
    char targetname[32];
    Format(targetname, 32, "light_dynamic_%d", entity);
    
    DispatchKeyValue(entity,"targetname", targetname);
    DispatchKeyValue(entity, "inner_cone", "0");
    DispatchKeyValue(entity, "cone", "80");
    DispatchKeyValue(entity, "brightness", "1");
    DispatchKeyValue(entity, "spotlight_radius", "150.0");
    DispatchKeyValue(entity, "pitch", "90");
    DispatchKeyValue(entity, "style", "1");
    DispatchKeyValue(entity, "_light", "255 0 0 255");

    DispatchKeyValueFloat(entity, "distance", g_fDistanceFlash);

    DispatchSpawn(entity);
    
    TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);

    AcceptEntityInput(entity, "TurnOn");
    
    SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", client);

    CreateTimer(0.1, Timer_PushCheck, entity, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT);

    Grenade_KillEntity(g_fDurationFlash, entity, "light_dynamic", targetname);
}

public Action Timer_PushCheck(Handle timer, int entity)
{
    if(!IsValidEdict(entity))
        return Plugin_Stop;

    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

    if(!IsValidClient(client))
        return Plugin_Stop;

    Push_Barrier(client, entity);

    return Plugin_Continue;
}

void Push_Barrier(int client, int entity)
{
    if(!IsPlayerAlive(client) || !ZR_IsClientHuman(client))
        return;

    float origin[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
    TE_SetupBeamRingPoint(origin, 10.0, g_fDistanceFlash, g_iBeamSprite, g_iHaloSprite, 0, 10, 0.6, 10.0, 0.5, redColor, 10, 0);
    TE_SendToAll();

    origin[2] -= 10.0;

    float targetOrigin[3];
    for(int target = 1; target <= MaxClients; target++)
    {
        if(!IsClientInGame(target) || !IsPlayerAlive(target) || ZR_IsClientHuman(target))
            continue;

        GetClientAbsOrigin(target, targetOrigin);
        targetOrigin[2] += 2.0;
        if(GetVectorDistance(origin, targetOrigin) <= g_fDistanceFlash)
        {
            Handle trace = TR_TraceRayFilterEx(origin, targetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, target);
        
            if((TR_DidHit(trace) && TR_GetEntityIndex(trace) == target) || (GetVectorDistance(origin, targetOrigin) <= 100.0))
            {
                KnockbackClient(target, origin);
                CloseHandle(trace);
            }
            else
            {
                CloseHandle(trace);
                
                GetClientEyePosition(target, targetOrigin);
                targetOrigin[2] -= 2.0;

                trace = TR_TraceRayFilterEx(origin, targetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, target);
            
                if((TR_DidHit(trace) && TR_GetEntityIndex(trace) == target) || (GetVectorDistance(origin, targetOrigin) <= 100.0))
                    KnockbackClient(target, origin);

                CloseHandle(trace);
            }
        }
    }
}

void KnockbackClient(int client, float pos[3])
{
    float clientloc[3];
    GetClientAbsOrigin(client, clientloc);
    KnockbackSetVelocity(client, pos, clientloc, 200.0);
}

void KnockbackSetVelocity(int client, const float startpoint[3], const float endpoint[3], float magnitude)
{
    float vector[3];
    MakeVectorFromPoints(startpoint, endpoint, vector);
    NormalizeVector(vector, vector);
    ScaleVector(vector, magnitude);
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, vector);
}