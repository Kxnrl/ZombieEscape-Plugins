//void OnFireFreeze(int entity)
public Action OnFireFreeze(Handle timer, int entity)
{
    if(!IsValidEdict(entity))
        return;
    
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    
    if(!IsValidClient(client))
        return;
    
    Call_StartForward(g_Forward[FREEZE]);
    Call_PushCell(client);
    Call_Finish();
}

public Action CreateEvent_DecoyDetonate(Handle timer, int iReference)
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

    if(StrEqual(Classname, "decoy_projectile"))
    {
        float origin[3];
        GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
        Decoy_Effect(client, origin);
        AcceptEntityInput(entity, "kill");
    }

    return Plugin_Stop;
}

void Decoy_Effect(int client, float origin[3])
{
    origin[2] += 10.0;
    
    if(!IsClientInGame(client) || !IsPlayerAlive(client) || !ZR_IsClientHuman(client))
        return;
    
    //CheckProtectFreezeNade(client, origin);
    
    float targetOrigin[3];
    
    for(int target = 1; target <= MaxClients; target++)
    {
        if(!IsClientInGame(target) || !IsPlayerAlive(target) || ZR_IsClientHuman(target))
        {
            continue;
        }
        
        GetClientAbsOrigin(target, targetOrigin);
        targetOrigin[2] += 2.0;
        float fDistance = GetVectorDistance(origin, targetOrigin);
        if(fDistance <= g_fDistanceDecoy)
        {
            Handle trace = TR_TraceRayFilterEx(origin, targetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, target);
        
            if((TR_DidHit(trace) && TR_GetEntityIndex(trace) == target) || (fDistance <= 100.0))
                FreezeClient(target, g_fDurationDecoy);
            else
            {
                CloseHandle(trace);
                
                GetClientEyePosition(target, targetOrigin);

                trace = TR_TraceRayFilterEx(origin, targetOrigin, MASK_SOLID, RayType_EndPoint, FilterTarget, target);
            
                if((TR_DidHit(trace) && TR_GetEntityIndex(trace) == target) || (fDistance <= 100.0))
                    FreezeClient(target, g_fDurationDecoy);
            }
            
            CloseHandle(trace);
        }
    }

    TE_SetupBeamRingPoint(origin, 10.0, g_fDistanceDecoy, g_iBeamSprite, g_iHaloSprite, 1, 1, 0.2, 100.0, 1.0, {0, 0, 255, 128}, 0, 0);
    TE_SendToAll();

    Decoy_LightCreate(origin);
}

void Decoy_LightCreate(float pos[3])   
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
    DispatchKeyValue(entity, "_light", "75 75 255 255");

    DispatchKeyValueFloat(entity, "distance", g_fDistanceDecoy);

    DispatchSpawn(entity);
    
    TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
    
    AcceptEntityInput(entity, "TurnOn");

    EmitSoundToAll(SOUND_FREEZE_EXPLODE, SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, pos);

    Grenade_KillEntity(g_fDurationDecoy, entity, "light_dynamic", targetname);
}

void FreezeClient(int client, float time)
{
    ClearTimer(g_hFreezeTimer[client]);

    SetEntityMoveType(client, MOVETYPE_NONE);
    TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, NULL_VECTOR);

    float vec[3];
    GetClientEyePosition(client, vec);
    vec[2] -= 50.0;

    EmitSoundToAll(SOUND_FREEZE, SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, vec);

    TE_SetupGlowSprite(vec, g_iGlowSprite, time, 2.0, 50);
    TE_SendToAll();

    g_hFreezeTimer[client] = CreateTimer(time, Timer_Unfreeze, client, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Unfreeze(Handle timer, int client)
{
    g_hFreezeTimer[client] = INVALID_HANDLE;
    
    if(IsClientInGame(client) && IsPlayerAlive(client))
        SetEntityMoveType(client, MOVETYPE_WALK);
}