#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <csgocolors>
#pragma newdecls required

#define CHECK_INTERVAL         5.0
#define CHECK_ADMIN(%1) (adminFlag == 0 ? GetUserFlagBits(%1)!=0 : (GetUserFlagBits(%1) & adminFlag || GetUserFlagBits(%1) & ADMFLAG_ROOT))

#define PREFIX    "\x01[\x10GoAFK\x01]"

ConVar goAFK_enable;
ConVar goAFK_mode;
ConVar goAFK_minPlayers;
ConVar goAFK_moveTime;
ConVar goAFK_kickTime;
ConVar goAFK_warnTime;
ConVar goAFK_disableStrafe;
ConVar goAFK_adminImmune;
ConVar goAFK_adminImmuneFlag;
ConVar goAFK_kickSpect;
ConVar goAFK_excludeBots;

bool enabled;
bool bIngame[MAXPLAYERS+1];
bool bIsCheckTimerEnabled;
bool bHasRoundJustEnded;
bool bAreStrafesDisabled;
bool bExcludeBotsFromChecking;
bool bIsBombPlanted;

float moveTime, kickTime, warnTime;
float afkTime[MAXPLAYERS+1] = {0.0, ...};
float EyePosition[MAXPLAYERS+1][3];
float ClientOrigin[MAXPLAYERS+1][3];
float g_fSpawnTime[MAXPLAYERS+1];

int countdown_buttons[MAXPLAYERS+1];
int pluginMode;
int immunityMode;
int minPlayers;
int old_buttons[MAXPLAYERS+1];
int ObserverMode[MAXPLAYERS+1];
int ObserverTarget[MAXPLAYERS+1];
int adminFlag;
int iMoveTime;
int iKickTime;
int iWarnTime;
int kickSpect;

public Plugin myinfo = {
    name = "goAFK Manager",
    author = "SUPER TIMOR/ credits: Dr.Api",
    description = "AFK Manager z dedykacją dla korzystających z goboosting.pl",
    version = "1.3",
    url = "https://goboosting.pl"
}

public void OnPluginStart() {
    LoadTranslations("goAFK.phrases");
    goAFK_enable = CreateConVar("goAFK_enabled", "1", "1 - ON /// 0 - OFF");
    goAFK_mode = CreateConVar("goAFK_mode", "1", "1 - KICK / 2 - MOVE TO SPECT")
    goAFK_kickSpect = CreateConVar("goAFK_kickSpect", "1", "If goAFK_mode = 1, include spectators to checkin' if AFK?")
    goAFK_minPlayers = CreateConVar("goAFK_min", "1", "Minimum amount of players to enable plugin actions")
    goAFK_moveTime = CreateConVar("goAFK_movetime", "150.0", "Time to move player");
    goAFK_kickTime = CreateConVar("goAFK_kicktime", "300.0", "Time to kick player");
    goAFK_warnTime = CreateConVar("goAFK_warntime", "120.0", "Time to warn player");    
    goAFK_disableStrafe = CreateConVar("goAFK_disablestrafe", "1", "1, if you want to include +left, +right afk guys to kick");
    goAFK_excludeBots = CreateConVar("goAFK_excludeBots", "1", "Exclude bots from plugin actions? \n1 = exclude\n 0 = include");
        
    goAFK_adminImmune = CreateConVar("goAFK_adminimmune", "0", "0 = no immunity for admins \n 1 = complete immunity for admins \n 2 = immunity for kick AFK admins \n 3 = immunity for moving AFK admins");
    goAFK_adminImmuneFlag = CreateConVar("goAFK_adminflag", "c", "Admin flag for immunity, blank = any flag");
    SetFlag(goAFK_adminImmuneFlag);
    
    HookEvent("player_spawn", Event_PlayerSpawn);
    HookEvent("player_team", Event_PlayerTeam);
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("round_start", Event_RoundStart);
    HookEvent("round_end", Event_RoundEnd);
    HookEvent("bomb_planted", Event_BombPlanted);
    
    HookConVarChange(goAFK_enable, Event_CvarChange);
    HookConVarChange(goAFK_mode, Event_CvarChange);
    HookConVarChange(goAFK_minPlayers, Event_CvarChange);
    HookConVarChange(goAFK_moveTime, Event_CvarChange);
    HookConVarChange(goAFK_kickTime, Event_CvarChange);
    HookConVarChange(goAFK_warnTime, Event_CvarChange);
    HookConVarChange(goAFK_disableStrafe, Event_CvarChange);
    HookConVarChange(goAFK_adminImmune, Event_CvarChange);
    HookConVarChange(goAFK_adminImmuneFlag, Event_CvarChange);
    HookConVarChange(goAFK_kickSpect, Event_CvarChange);    
    HookConVarChange(goAFK_excludeBots, Event_CvarChange);    
    AutoExecConfig(true, "GoAFK", "sourcemod");
    
    bIsCheckTimerEnabled = false;
}

public void Event_CvarChange(Handle cvar, const char[] oldValue, const char[] newValue) {
    CvarUpdate();
}

public void OnConfigsExecuted() {
    CvarUpdate();
}

public void OnMapStart() {
    AutoExecConfig(true, "GoAFK", "sourcemod");    
    bIsCheckTimerEnabled = false;
    CvarUpdate();
}

void CvarUpdate() {
    enabled = GetConVarBool(goAFK_enable);
    pluginMode = GetConVarInt(goAFK_mode);
    minPlayers = GetConVarInt(goAFK_minPlayers);
    immunityMode = GetConVarInt(goAFK_adminImmune);
    moveTime = GetConVarFloat(goAFK_moveTime);
    kickTime = GetConVarFloat(goAFK_kickTime);
    warnTime = GetConVarFloat(goAFK_warnTime);
    iKickTime = RoundFloat(kickTime);
    iMoveTime = RoundFloat(moveTime);
    iWarnTime = RoundFloat(warnTime);
    bAreStrafesDisabled = GetConVarBool(goAFK_disableStrafe);
    kickSpect = GetConVarBool(goAFK_kickSpect);
    bExcludeBotsFromChecking = GetConVarBool(goAFK_excludeBots);
    
    SetFlag(goAFK_adminImmuneFlag);
    if(enabled) {
        if(!bIsCheckTimerEnabled) {
            bIsCheckTimerEnabled = true;
            CreateTimer(CHECK_INTERVAL, Timer_CheckPlayerAfkManagerCsgo, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
            
            if(bAreStrafesDisabled)
                CreateTimer(1.0, Timer_KeyCheck, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);            
        }
        
        for (int i = 1; i <= MaxClients; i++) {
            bIngame[i] = false;
            
            if (IsClientConnected(i) && IsClientInGame(i))
                InitializeClient(i);
        }
    }
}

void SetFlag(ConVar convar) {
    char flags[4];
    AdminFlag flag;
    GetConVarString(convar, flags, sizeof(flags));
    if (flags[0]!='\0' && FindFlagByChar(flags[0], flag))
         adminFlag = FlagToBit(flag);
    else 
        adminFlag = 0;
}

public void OnClientPostAdminCheck(int client) {
    if(enabled) {
        if(IsFakeClient(client) && bExcludeBotsFromChecking)
            return;
        else
            bIngame[client] = true;
    }
}

public void OnClientDisconnect(int client) {
    if(enabled)
        bIngame[client] = false;
}

public void Event_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast) {
    if(enabled) {
        int client = GetClientOfUserId(GetEventInt(event, "userid"));
        g_fSpawnTime[client] = GetEngineTime();
        
        if(IsValidClient(client) && !IsFakeClient(client) && !IsClientObserver(client) && IsPlayerAlive(client))
            ResetClientVariables(client);
    }
}

public void Event_PlayerTeam(Handle event, const char[] name, bool dontBroadcast) {
    if(enabled) {
        int client = GetClientOfUserId(GetEventInt(event, "userid"));
        int team = GetEventInt(event, "team");
        
        if(IsValidClient(client) && !IsFakeClient(client)) {
            if(!bIngame[client])
                InitializeClient(client);
            
            if(team != 1) {
                if(bIngame[client])
                    ResetClientVariables(client);
            }
            else {
                GetClientEyeAngles(client, EyePosition[client]);
                ObserverMode[client] = GetEntProp(client, Prop_Send, "m_iObserverMode");
                ObserverTarget[client] = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
            }
        }
        CreateTimer(2.0, Timer_CheckAlivePlayers);
    }
}

public void Event_PlayerDeath(Handle event, const char[] name, bool dontBroadcast) {
    if(enabled) {
        int client = GetClientOfUserId(GetEventInt(event, "userid"));
        ResetClientVariables(client);
        CreateTimer(2.0, Timer_CheckAlivePlayers);
    }
}

public void Event_RoundStart(Handle event, const char[] name, bool dontBroadcast) {
    bHasRoundJustEnded = false;
    bIsBombPlanted = false;
}

public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast) {
    bHasRoundJustEnded = true;
}

public Action Event_BombPlanted(Event event, char[] name, bool dontBroadcast) {
    bIsBombPlanted = true;
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2]) {
    
    if(buttons != old_buttons[client] && bAreStrafesDisabled)  {
        countdown_buttons[client] = 0;
        old_buttons[client] = buttons;
    }
}

bool CheckObserverAFKCsgo(int client) {
    int lastTarget; 
    int lastObserverMode = ObserverMode[client];
    ObserverMode[client] = GetEntProp(client, Prop_Send, "m_iObserverMode");
    
    if(lastObserverMode > 0 && ObserverMode[client] != lastObserverMode)
        return false;

    float EyeLocation[3];
    EyeLocation = EyePosition[client];
    
    if(ObserverMode[client] == 6)
        GetClientEyeAngles(client, EyePosition[client]);
    else
    {
        lastTarget = ObserverTarget[client];
        ObserverTarget[client]     = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

        if(lastObserverMode == 0 && lastTarget == 0)
            return true;

        if(lastTarget > 0 && ObserverTarget[client] != lastTarget) {
            if (lastTarget > MaxClients || !IsClientConnected(lastTarget) || !IsClientInGame(lastTarget))
                return false;
            return (!IsPlayerAlive(lastTarget));
        }
    }

    if((EyePosition[client][0] == EyeLocation[0]) && (EyePosition[client][1] == EyeLocation[1]) && (EyePosition[client][2] == EyeLocation[2]))
        return true;
    
    return false;
}

public Action Timer_CheckPlayerAfkManagerCsgo(Handle timer, any data) {
    int PlayersNow = GetClientCount(true);  
    
    if(minPlayers > PlayersNow)
        return Plugin_Continue;
        
    int team; 
    float timeleft;
    
    float fEyePosition[3]; 
    float fClientOrigin[3];
    
    for(int client = 1; client <= MaxClients; client++) {
        if(!bIngame[client] || !IsClientInGame(client))
            continue;
            
        team = GetClientTeam(client);
        if(IsClientObserver(client)) {    
            if(team > 1 && !IsPlayerAlive(client))
                continue; 
            
            if((team == 0 || CheckObserverAFKCsgo(client) && kickSpect))
                afkTime[client] += CHECK_INTERVAL;
            else {
                afkTime[client] = 0.0;
                continue;
            }
        }
        else {
            fEyePosition = EyePosition[client];
            fClientOrigin = ClientOrigin[client];
            GetClientEyeAngles(client, EyePosition[client]);
            GetClientAbsOrigin(client, ClientOrigin[client]);

            if ((EyePosition[client][0] == fEyePosition[0]) && 
                (EyePosition[client][1] == fEyePosition[1]) &&
                (EyePosition[client][2] == fEyePosition[2]) &&
                !(GetEntityFlags(client) & FL_FROZEN))
                    afkTime[client] += CHECK_INTERVAL;
            else {
                afkTime[client] = 0.0;
                continue;
            }
        }
        switch(pluginMode) {
            case 1: {
                if(!immunityMode || immunityMode == 3 || !CHECK_ADMIN(client)) {
                    timeleft = kickTime - afkTime[client];
                    if(timeleft > 0.0) {
                        if(timeleft <= iWarnTime)
                            CPrintToChat(client, "%t", "Kick_Warning", RoundToFloor(timeleft));
                    }
                    else {
                        char clientName[MAX_NAME_LENGTH+4];
                        Format(clientName,sizeof(clientName),"%N",client);
                        CPrintToChatAll("%t", "Kick_Announce", clientName);
                        KickClient(client, "%t", "Kick_Message");
                        CreateTimer(2.0, Timer_CheckAlivePlayers);
                    }
                }
            }
            case 2: {
                if(team > 1 && (!immunityMode || immunityMode == 2 || !CHECK_ADMIN(client))) {
                    timeleft = moveTime - afkTime[client];
                    if(timeleft > 0.0) {
                        if(timeleft <= iWarnTime)
                            CPrintToChat(client, "%t", "Move_Warning", RoundToFloor(timeleft));
                    }
                    else {
                        char clientName[MAX_NAME_LENGTH+4];
                        Format(clientName,sizeof(clientName),"%N",client);
                        CPrintToChatAll("%t", "Move_Announce", clientName);    
                        int death = GetEntProp(client, Prop_Data, "m_iDeaths");
                        int frags = GetEntProp(client, Prop_Data, "m_iFrags");
                        ChangeClientTeam(client, 1);
                        SetEntProp(client, Prop_Data, "m_iFrags", frags);
                        SetEntProp(client, Prop_Data, "m_iDeaths", death);
                        CreateTimer(2.0, Timer_CheckAlivePlayers);
                    }
                }
            }
        }
    }
    return Plugin_Continue;
}

public Action Timer_KeyCheck(Handle Timer) {
    for(int i = 1; i <= MaxClients; i++) {
        if(!IsClientInGame(i) || !IsPlayerAlive(i))
            continue;
        
        if(bExcludeBotsFromChecking && IsFakeClient(i))
            continue;
        
        if(afkTime[i] != 0.0)
            continue;
            
        char clientName[MAX_NAME_LENGTH+4];
        Format(clientName,sizeof(clientName),"%N", i);
        switch(pluginMode) {
            case 1: {
                if(!immunityMode || immunityMode == 3 || !CHECK_ADMIN(i)) {
                    if(countdown_buttons[i] == iKickTime) {
                        CPrintToChatAll("%t", "Kick_Announce", clientName);
                        KickClient(i, "%t", "Kick_Message");
                        CreateTimer(2.0, Timer_CheckAlivePlayers);
                    }
                    else if(countdown_buttons[i] < iKickTime) {
                        if(countdown_buttons[i] % 5 == 0) {
                                int timeleft = iKickTime - countdown_buttons[i];
                                if(timeleft <= iWarnTime)
                                    CPrintToChat(i, "%t", "Kick_Warning", timeleft);
                        }
                    }
                }
            }
            case 2: {
                if(!immunityMode || immunityMode == 2 || !CHECK_ADMIN(i)) {
                    if(countdown_buttons[i] == iMoveTime) {
                        CPrintToChatAll("%t", "Move_Announce", clientName);        
                        int death = GetEntProp(i, Prop_Data, "m_iDeaths");
                        int frags = GetEntProp(i, Prop_Data, "m_iFrags");
                        ChangeClientTeam(i, 1);
                        SetEntProp(i, Prop_Data, "m_iFrags", frags);
                        SetEntProp(i, Prop_Data, "m_iDeaths", death);
                        CreateTimer(2.0, Timer_CheckAlivePlayers);
                    }
                    else if(countdown_buttons[i] < iMoveTime) { 
                        if(countdown_buttons[i]%5 == 0) {
                                int timeleft = iMoveTime - iWarnTime;
                                if(countdown_buttons[i] > iWarnTime)
                                    CPrintToChat(i, "%t", "Move_Warning", timeleft);
                        }
                    }
                }
            }
        }
        countdown_buttons[i]++;
    }
}

public Action Timer_CheckAlivePlayers(Handle timer) {
    CheckAlivePlayers();
}

void ResetClientVariables(int client) {
    afkTime[client]    = 0.0;
    for(int i = 0; i < 3; i++)
        EyePosition[client][i]     = 0.0;
        
    ObserverMode[client] = ObserverTarget[client] = 0;
    countdown_buttons[client] = 0;
}

void InitializeClient(int client) {
    if(enabled) {
        if(IsFakeClient(client) && bExcludeBotsFromChecking)
            return;
            
        bIngame[client] = true;
        ResetClientVariables(client);
    }
}
public bool IsValidClient(int client) {
    if(IsClientInGame(client) && client >= 1 && client <= MaxClients)
        return true;

    return false;
}

int GetPlayersAlive(int team, char[] bot) {
    int iCount = 0;
    for(int i = 1; i <= MaxClients; i++)  {
        if(StrEqual(bot, "player", false)) {
            if( IsValidClient(i) && !IsFakeClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == team)  {
                iCount++; 
            }
        }
        else if(StrEqual(bot, "bot", false)) {
            if( IsValidClient(i) && IsFakeClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == team)  {
                iCount++; 
            }
        }
        else if(StrEqual(bot, "both", false)) {
            if( IsValidClient(i) && IsPlayerAlive(i) && GetClientTeam(i) == team)  {
                iCount++; 
            }
        }
    }
    return iCount; 
}

void CheckAlivePlayers() {
    int CT_Players = GetPlayersAlive(CS_TEAM_CT, "both");
    int T_Players = GetPlayersAlive(CS_TEAM_T, "both");
    int players = CT_Players + T_Players;
    if(!bHasRoundJustEnded) {
        if(players <= 0)
            CS_TerminateRound(1.0, CSRoundEnd_Draw);
        else if(CT_Players == 0)
            CS_TerminateRound(1.0, CSRoundEnd_TerroristWin);
        else if(T_Players == 0 && !bIsBombPlanted)
            CS_TerminateRound(1.0, CSRoundEnd_CTWin);
    }
}