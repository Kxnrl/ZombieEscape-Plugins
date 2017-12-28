public void Event_TagrenadeDetonate(Handle event, const char[] name, bool dontBroadcast)
{
    int entity = GetEventInt(event, "entityid");
    
    float m_fOrigin[3];
    
    m_fOrigin[0] = GetEventFloat(event, "x");
    m_fOrigin[1] = GetEventFloat(event, "y");
    m_fOrigin[2] = GetEventFloat(event, "z")+60.0;
    
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    
    AcceptEntityInput(entity, "Kill");
    
    CreateBlackHole(client, m_fOrigin);
}

void CreateBlackHole(int client, float fPos[3])
{
    PrintToChatAll("CreateBlackHole -> %.2f %.2f %.2f", fPos[0], fPos[1], fPos[2]);
    int particle = CreateEntityByName("info_particle_system");
    
    SetEntPropEnt(particle, Prop_Data, "m_hOwnerEntity", client);

    DispatchKeyValue(particle , "effect_name", "magia_gravedad_ON");
    DispatchKeyValue(particle , "start_active", "1");

    DispatchSpawn(particle);

    TeleportEntity(particle, fPos, NULL_VECTOR, NULL_VECTOR);

    ActivateEntity(particle);

    //AcceptEntityInput(particle, "Start");

    char targetname[32];
    Format(targetname, 32, "blackhole_%d", particle);
    DispatchKeyValue(particle,"targetname", targetname);

    //CreateTimer(0.03, Timer_BlackHold, particle, TIMER_REPEAT);
    RequestFrame(BlackHole, particle);
    Grenade_KillEntity(10.0, particle, "info_particle_system", targetname);
}
/*
public Action Timer_BlackHold(Handle timer, int entity)
{
    if(!IsValidEdict(entity))
        return Plugin_Stop;
    
    float origin[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
    
    EffectBlackHole(origin);
    
    return Plugin_Continue;
}
*/

void BlackHole(int entity)
{
    if(!IsValidEdict(entity))
        return;
    
    float origin[3];
    GetEntPropVector(entity, Prop_Send, "m_vecOrigin", origin);
    
    EffectBlackHole(origin);
    RequestFrame(BlackHole, entity);
}
void EffectBlackHole(float fPos[3])
{
    PrintToServer("EffectBlackHole -> %f %f %f", fPos[0], fPos[1], fPos[2]);
    for(int client = 1; client <= MaxClients; client++)
    {
        if(!IsClientInGame(client) || !IsPlayerAlive(client) || !ZR_IsClientZombie(client))
            continue;

        float m_fTargetOrigin[3];
        GetClientAbsOrigin(client, m_fTargetOrigin);

        float dist = GetVectorDistance(m_fTargetOrigin, fPos);
        if(dist > 500.0)
            continue;

        PushPlayersToBlackHole(client, m_fTargetOrigin, fPos, dist);
    }
}

void PushPlayersToBlackHole(int client, float clientPos[3], const float tPos[3], float distance)
{
    float blackholePos[3];
    blackholePos[0] = tPos[0];
    blackholePos[1] = tPos[1];
    blackholePos[2] = tPos[2]+10.0;

    if(20.0 < distance < 500.0)
    {
        ShakeScreen(client, 10.0, 0.1, 0.7);

        SetEntPropEnt(client, Prop_Data, "m_hGroundEntity", -1);

        float direction[3];
        SubtractVectors(blackholePos, clientPos, direction);
        
        float gravityForce = 780.0 * (((350.0 * 500.0 / 50) * 20.0) / GetVectorLength(direction,true));
        gravityForce = gravityForce / 50.0;
        
        NormalizeVector(direction, direction);
        ScaleVector(direction, gravityForce);

        float playerVel[3];
        GetEntPropVector(client, Prop_Data, "m_vecVelocity", playerVel);
        NegateVector(direction);
        ScaleVector(direction, distance / 300);
        SubtractVectors(playerVel, direction, direction);
        TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, direction);
        
        PrintToServer("PushPlayersToBlackHole -> %d", client);
    }
    else
    {
        ShakeScreen(client, 15.0, 0.1, 0.7);
        PrintToServer("PushPlayersToBlackHole -> %d [Center]", client);
    }
}


void ShakeScreen(int client, float intensity, float duration, float frequency)
{
    Handle pb;
    if((pb = StartMessageOne("Shake", client)) != null)
    {
        PbSetFloat(pb, "local_amplitude", intensity);
        PbSetFloat(pb, "duration", duration);
        PbSetFloat(pb, "frequency", frequency);
        EndMessage();
    }
}