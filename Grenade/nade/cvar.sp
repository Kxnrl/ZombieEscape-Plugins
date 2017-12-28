void ConVar_OnPluginStart()
{
    CVAR_DISTANCE_FLASH = CreateConVar("zr_maoling_distance_flash", "250.0", "Range of the barrier",     _, true, 150.0, true, 400.0);
    CVAR_DURATION_FLASH = CreateConVar("zr_maoling_duration_flash", "3.0",   "Duration of the barrier",  _, true,   2.0, true,   5.0);
    CVAR_DISTANCE_DECOY = CreateConVar("zr_maoling_distance_decoy", "250.0", "Range of the freezing",    _, true, 200.0, true, 350.0);
    CVAR_DURATION_DECOY = CreateConVar("zr_maoling_duration_decoy", "2.5",   "Duration of the freezing", _, true,   2.0, true,   3.0);
    CVAR_DISTANCE_SMOKE = CreateConVar("zr_maoling_distance_smoke", "300.0", "Range of the poison",      _, true, 200.0, true, 500.0);
    CVAR_DURATION_SMOKE = CreateConVar("zr_maoling_duration_smoke", "4.0",   "Duration of the poison",   _, true,   3.0, true,   5.0);

    HookConVarChange(CVAR_DISTANCE_FLASH, OnSettingChanged);
    HookConVarChange(CVAR_DURATION_FLASH, OnSettingChanged);
    HookConVarChange(CVAR_DISTANCE_DECOY, OnSettingChanged);
    HookConVarChange(CVAR_DURATION_DECOY, OnSettingChanged);
    HookConVarChange(CVAR_DISTANCE_SMOKE, OnSettingChanged);
    HookConVarChange(CVAR_DURATION_SMOKE, OnSettingChanged);
}

public void OnConfigsExecuted()
{
    g_fDistanceFlash = GetConVarFloat(CVAR_DISTANCE_FLASH);
    g_fDurationFlash = GetConVarFloat(CVAR_DURATION_FLASH);
    g_fDistanceDecoy = GetConVarFloat(CVAR_DISTANCE_DECOY);
    g_fDurationDecoy = GetConVarFloat(CVAR_DURATION_DECOY);
    g_fDistanceSmoke = GetConVarFloat(CVAR_DISTANCE_SMOKE);
    g_fDurationSmoke = GetConVarFloat(CVAR_DURATION_SMOKE);
}

public void OnSettingChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
    g_fDistanceFlash = GetConVarFloat(CVAR_DISTANCE_FLASH);
    g_fDurationFlash = GetConVarFloat(CVAR_DURATION_FLASH);
    g_fDistanceDecoy = GetConVarFloat(CVAR_DISTANCE_DECOY);
    g_fDurationDecoy = GetConVarFloat(CVAR_DURATION_DECOY);
    g_fDistanceSmoke = GetConVarFloat(CVAR_DISTANCE_SMOKE);
    g_fDurationSmoke = GetConVarFloat(CVAR_DURATION_SMOKE);
}