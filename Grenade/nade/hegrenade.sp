//void OnFireHE(int entity)
public Action OnFireHE(Handle timer, int entity)
{
    if(!IsValidEdict(entity))
        return;
    
    int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
    
    if(!IsValidClient(client))
        return;
    
    Call_StartForward(g_Forward[HEGRENADE]);
    Call_PushCell(client);
    Call_Finish();
}