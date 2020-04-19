#include <sdkhooks>
#include <ff2_helper>
#include <freak_fortress_2_subplugin>

#define this_ability_name "ff2_fakedeath"

bool IsBatFF2;
bool CanFireFakeDeath[MAXCLIENTS];
bool IsActive;
bool isFakeEvent;

//The only way to do it without SourceScramble::MemoryBlock(). i tried to find find an offset that can let me peek at "weapon" string, but then i gave up
public void OnPluginStart2()
{
	#if defined _FFBAT_included
	int Ver[3];
	FF2_GetForkVersion(Ver);
	if(Ver[0] && Ver[1])
		IsBatFF2 = true;
	#endif
	
	HookEvent("player_hurt", Post_PlayerHurt, EventHookMode_Post);
	HookEvent("player_death", Post_PlayerDeath, EventHookMode_Post);
	HookEvent("arena_round_start", Post_RoundStart, EventHookMode_Post);
	HookEvent("arena_win_panel", Post_RoundEnd, EventHookMode_PostNoCopy);
	if(IsRoundActive())
		Post_RoundStart(null, "plugin_lateload", false);
}

public Action FF2_OnAbility2(int boss, const char[] Plugin_Name, const char[] Ability_Name, int status) {
}

public void Post_RoundStart(Event hEvent, const char[] sName, bool broadcast) 
{
	for(int x = 1; x <= MaxClients; x++) 
	{
		if(!IsClientInGame(x))
			continue;
		
		FF2Prep player = FF2Prep(x);
		if(!player.HasAbility(this_plugin_name, this_ability_name))
			continue;
		
		if(!IsActive)	IsActive = true;
		CanFireFakeDeath[x] = true;
	}
}

public void Post_RoundEnd(Event hevent, const char[] name, bool dontBroadcast)
{
	if(IsActive)
	{
		for(int x = 1; x <= MaxClients; x++) {
			if(CanFireFakeDeath[x])	CanFireFakeDeath[x] = false;
		}
		IsActive = false;
	}
}

public void Post_PlayerDeath(Event hEvent, const char[] sName, bool broadcast) 
{
	if(!IsActive)
		return;
	
	int client = GetClientOfUserId(hEvent.GetInt("attacker"));
	FF2Prep boss = FF2Prep(client);
	if(!boss.HasAbility(this_plugin_name, this_ability_name))
		return;
	
	static char buffer[64];
	
	int victim = GetClientOfUserId(hEvent.GetInt("userid"));
	float vecPos[3];
	GetClientEyePosition(victim, vecPos);
	
	boss.GetArgS(this_plugin_name, this_ability_name, "particle", 1, buffer, sizeof(buffer));
	FixParticleTeam(buffer, sizeof(buffer), TF2_GetClientTeam(client));
	CreateTimedParticle(victim, buffer, vecPos, 1.4);
	switch(isFakeEvent)
	{
		case true: {
			if(FF2_RandomSound("sound_fake_death", buffer, sizeof(buffer), boss.boss))
				FF2_EmitVoiceToAll2(buffer, client);
			
		}
		case false: {
			if(FF2_RandomSound("sound_real_death", buffer, sizeof(buffer), boss.boss))
				FF2_EmitVoiceToAll2(buffer, client);
		}
	}
}

public void Post_PlayerHurt(Event hEvent, const char[] sName, bool broadcast) 
{
	int ui_attacker = hEvent.GetInt("attacker");
	int attacker = GetClientOfUserId(ui_attacker);
	if(!attacker || !IsClientInGame(attacker)) 
		return;
	
	FF2Prep boss = FF2Prep(attacker);
	if(!boss.HasAbility(this_plugin_name, this_ability_name))
		return;
	
	if(!CanFireFakeDeath[attacker])
		return;
	
	int ui_victim = hEvent.GetInt("userid");
	int health = hEvent.GetInt("health");
	if(health <= 0)
		return;
	
	int min = boss.GetArgI(this_plugin_name, this_ability_name, "min", 2, 25);
	int damageamount = hEvent.GetInt("damageamount");
	if(damageamount <= min)
		return;
	int weaponid = hEvent.GetInt("weaponid");
	if(damageamount > 0)
	{
		static char weaponName[64], weapons[32];
		
		int wep = GetEntPropEnt(attacker, Prop_Send, "m_hActiveWeapon");
		min = GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex");
		IntToString(min, weaponName, sizeof(weaponName));
		if(!boss.GetArgS(this_plugin_name, this_ability_name, weaponName, 3, weapons, sizeof(weapons)))
			return;
		
		FireFakeDeathEvent(ui_victim, ui_attacker, weaponid, weapons, DMG_CRIT | DMG_PREVENT_PHYSICS_FORCE);
	}
	return;
}

void FireFakeDeathEvent(int victim, int attacker, int weaponid, char[] weapon, int damagebits)
{
	Event DeathNotice = CreateEvent("player_death", true);
	if(DeathNotice == null)
	{
		FF2_LogError("[FF2] Attempted to create an invalid Event for \"player_death\"!");
		return;
	}
	DeathNotice.SetInt("userid", victim);
	DeathNotice.SetInt("attacker", attacker);
	DeathNotice.SetInt("weaponid", weaponid);
	DeathNotice.SetString("weapon", weapon)
	DeathNotice.SetInt("damagebits", damagebits);
	isFakeEvent = true;
	DeathNotice.Fire(false);
	isFakeEvent = false;
}

public void OnEntityCreated(int entity, const char[] cls)
{
	if(!strcmp(cls, "entity_revivemarker"))
		if(isFakeEvent)
			SDKHook(entity, SDKHook_Spawn, OnReviveMarkerCreated);
}

public void OnReviveMarkerCreated(int marker)
{
	RemoveEntity(marker);
	SDKUnhook(entity, SDKHook_Spawn, OnReviveMarkerCreated);
}

stock void FF2_EmitVoiceToAll2(const char[] sound, int entity = SOUND_FROM_PLAYER)
{
#if defined _FFBAT_included
	if(IsBatFF2)
		FF2_EmitVoiceToAll(sound, entity);
	else EmitSoundToAll(sound, entity);
#else
	EmitSoundToAll(sound, entity);
#endif
}

stock void FixParticleTeam(char[] buffer, int size, const TFTeam iTeam)
{
	if(StrContains(buffer, "...") == -1)
		return;
	switch(iTeam)
	{
		case TFTeam_Red: {
			ReplaceString(buffer, size, "...", "red");
			return;
		}
		case TFTeam_Blue: {
			ReplaceString(buffer, size, "...", "blue");
			return;
		}
	}
}

stock void CreateTimedParticle(int owner, const char[] Name, float SpawnPos[3], float duration)
{
	CreateTimer(duration, Timer_KillEntity, EntIndexToEntRef(AttachParticle(owner, Name, SpawnPos)), TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_KillEntity(Handle timer, any EntRef)
{
	int entity = EntRefToEntIndex(EntRef);
	if(IsValidEntity(entity))
		RemoveEntity(entity);
}

stock int AttachParticle(int owner, const char[] ParticleName, float SpawnPos[3])
{
	int entity = CreateEntityByName("info_particle_system");

	TeleportEntity(entity, SpawnPos, NULL_VECTOR, NULL_VECTOR);

	static char buffer[64];
	FormatEx(buffer, sizeof(buffer), "target%i", owner);
	DispatchKeyValue(owner, "targetname", buffer);

	DispatchKeyValue(entity, "targetname", "tf2particle");
	DispatchKeyValue(entity, "parentname", buffer);
	DispatchKeyValue(entity, "effect_name", ParticleName);
	DispatchSpawn(entity);
	
	SetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity", owner);
	ActivateEntity(entity);
	AcceptEntityInput(entity, "start");
	
	return entity; 
}