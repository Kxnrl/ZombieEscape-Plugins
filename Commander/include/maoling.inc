#include <sdktools>

stock bool IsValidClient(int client)
{
    if(client > MaxClients || client < 1)
        return false;

    if(!IsClientInGame(client))
        return false;
    
    if(IsFakeClient(client))
        return false;
    
    if(IsClientSourceTV(client))
        return false;

    return true;
}

stock void ReplaceColorsCode(char[] buffer, int maxLen)
{
    ReplaceString(buffer, maxLen, "{normal}", "\x01", false);
    ReplaceString(buffer, maxLen, "{default}", "\x01", false);
    ReplaceString(buffer, maxLen, "{white}", "\x01", false);
    ReplaceString(buffer, maxLen, "{darkred}", "\x02", false);
    ReplaceString(buffer, maxLen, "{pink}", "\x03", false);
    ReplaceString(buffer, maxLen, "{green}", "\x04", false);
    ReplaceString(buffer, maxLen, "{lime}", "\x05", false);
    ReplaceString(buffer, maxLen, "{yellow}", "\x05", false);
    ReplaceString(buffer, maxLen, "{lightgreen}", "\x06", false);
    ReplaceString(buffer, maxLen, "{lightred}", "\x07", false);
    ReplaceString(buffer, maxLen, "{red}", "\x07", false);
    ReplaceString(buffer, maxLen, "{gray}", "\x08", false);
    ReplaceString(buffer, maxLen, "{grey}", "\x08", false);
    ReplaceString(buffer, maxLen, "{olive}", "\x09", false);
    ReplaceString(buffer, maxLen, "{orange}", "\x10", false);
    ReplaceString(buffer, maxLen, "{purple}", "\x0E", false);
    ReplaceString(buffer, maxLen, "{lightblue}", "\x0B", false);
    ReplaceString(buffer, maxLen, "{blue}", "\x0C", false);
}

stock void ClearTimer(Handle &timer)
{
    if(timer != INVALID_HANDLE)
    {
        KillTimer(timer);
        timer = INVALID_HANDLE;
    }
}

stock int GetClientAimTargetPos(int client, float pos[3]) 
{
    if(client < 1) 
        return -1;

    float vAngles[3];
    float vOrigin[3];
    
    GetClientEyePosition(client,vOrigin);
    GetClientEyeAngles(client, vAngles);
    
    Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SHOT, RayType_Infinite, TraceFilterAllEntities, client);
    
    TR_GetEndPosition(pos, trace);
    
    int entity = TR_GetEntityIndex(trace);
    
    CloseHandle(trace);
    
    return entity;
}

public bool TraceFilterAllEntities(int entity, int contentsMask, int client)
{
    if(entity == client || entity > MaxClients || !IsClientInGame(entity) || !IsPlayerAlive(entity))

        return false;

    return true;
}

stock void SetMenuTitleEx(Handle menu, const char[] fmt, any ...)
{
    char m_szBuffer[256];
    VFormat(m_szBuffer, 256, fmt, 3);
    
    if(GetEngineVersion() == Engine_CSGO)
        Format(m_szBuffer, 256, "%s\n　", m_szBuffer);
    else
    {
        ReplaceString(m_szBuffer, 256, "\n \n", " - ");
        ReplaceString(m_szBuffer, 256, "\n", " - ");
    }
    
    SetMenuTitle(menu, m_szBuffer);
}

stock void tPrintToChat(int client, const char[] szMessage, any ...)
{
    if(client <= 0 || client > MaxClients)
        ThrowError("Invalid client index %d", client);

    if(!IsClientInGame(client))
        ThrowError("Client %d is not in game", client);

    char szBuffer[256];

    SetGlobalTransTarget(client);
    VFormat(szBuffer, 256, szMessage, 3);
    ReplaceColorsCode(szBuffer, 256);
    PrintToChat(client, szBuffer);
}

stock void tPrintToChatAll(const char[] szMessage, any ...)
{
    char szBuffer[256];

    for(int i = 1; i <= MaxClients; i++)
    {
        if(IsClientInGame(i) && !IsFakeClient(i))
        {
            SetGlobalTransTarget(i);            
            VFormat(szBuffer, 256, szMessage, 2);
            ReplaceColorsCode(szBuffer, 256);
            PrintToChat(i, "%s", szBuffer);
        }
    }
}