#if defined _01PX_Included
 #endinput
#endif
#define _01PX_Included

#include <tf2_stocks>
#include <freak_fortress_2>

#define IsEmptyString(%1)	(%1[0]=='\0')
#define BossToClient(%1)	(GetClientOfUserId(FF2_GetBossUserId(%1)))
#define ClientToBoss(%1)	(FF2_GetBossIndex(%1))
#define Dereference(%1)		(view_as<Address>(LoadFromAddress(%1, NumberType_Int32)))
#define MAXCLIENTS			(MAXPLAYERS+1)
#define INACTIVE				1000000000.0

methodmap FF2Prep {
	public FF2Prep(int player, bool index=true) {
		return view_as<FF2Prep>(index ? ClientToBoss(player):player);
	}
	
	property int boss {
		public get() {
			return view_as<int>(this);
		}
	}
	
	property int Index {
		public get() {
			return view_as<int>(BossToClient(this.boss));
		}
	}

	public bool HasAbility(const char[] plugin, const char[] ability) {
		if(this.boss < 0)
			return false;
		return FF2_HasAbility(this.boss, plugin, ability);
	}
	
	public int GetArgI(const char[] plugin, const char[] ability, const char[] key, int arg = -10, int def) {
		return (GetFeatureStatus(FeatureType_Native, "FF2_GetArgNamedI") == FeatureStatus_Available ? 
		FF2_GetArgNamedI(this.boss, plugin, ability, key, def):FF2_GetAbilityArgument(this.boss, plugin, ability, arg = -10, def));
	}
	
	public float GetArgF(const char[] plugin, const char[] ability, const char[] key, int arg = -10, float def) {
		return (GetFeatureStatus(FeatureType_Native, "FF2_GetArgNamedF") == FeatureStatus_Available ? 
		FF2_GetArgNamedF(this.boss, plugin, ability, key, def):FF2_GetAbilityArgumentFloat(this.boss, plugin, ability, arg = -10, def));
	}
	
	public bool GetArgS(const char[] plugin, const char[] ability, const char[] key, int arg = -10, char[] buffer, int size) {
		switch(GetFeatureStatus(FeatureType_Native, "FF2_GetArgNamedS")) 
		{
			case FeatureStatus_Available: {
				FF2_GetArgNamedS(this.boss, plugin, ability, key, buffer, size);
				if(IsEmptyString(buffer))
					FF2_GetAbilityArgumentString(this.boss, plugin, ability, arg, buffer, size);
			}
			default: {
				FF2_GetAbilityArgumentString(this.boss, plugin, ability, arg, buffer, size);
			}
		}
		return (!IsEmptyString(buffer));
	}
	
	public int GetButton(const char[] plugin, const char[] ability, const char[] key, int arg = -10, int def) {
		char buffer[32];
		if(!this.GetArgS(plugin, ability, key, arg, buffer, sizeof(buffer)))
			return def;
		if(!strcmp(buffer, "reload"))
			return IN_RELOAD;
		else if(!strcmp(buffer, "attack3"))
			return IN_ATTACK3;
		else if(!strcmp(buffer, "attack2"))
			return IN_ATTACK2;
		return def;
	}
	
	public bool PrepareString(int type, char[] buffer, int size)
	{
		switch(type) {
			case 0 : return !!ReplaceString(buffer, size, "\\n", "\n");
			case 1 :	return PrecacheSound(buffer);
			default: return false;
		}
	}
}
	
enum Validity {
	Invalid,
	Any,
	AnyAlive,
	IsRed,
	IsBlu,
	IsBoss
};

stock bool ValidatePlayer(int client, Validity Type)
{
	if(client <= 0 || client > MaxClients)
		return false;
	switch(Type)
	{
		case Any:		return IsClientInGame(client);
		case AnyAlive: return (IsClientInGame(client) && IsPlayerAlive(client));
		case IsRed:		return TF2_GetClientTeam(client)==TFTeam_Red;
		case IsBlu:		return TF2_GetClientTeam(client)==TFTeam_Blue;
		case IsBoss:	return FF2_GetBossIndex(client)>=0;
	}
	return false;
}

stock bool IsRoundActive()
{
	return (FF2_IsFF2Enabled() && FF2_GetRoundState() == 1)
}
