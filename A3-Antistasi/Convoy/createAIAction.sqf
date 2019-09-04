params ["_destination", "_type", "_side", ["_arguments", []]];

/* params
*   _destination : MARKER or POS; the marker or position the AI should take AI on
*   _type : STRING; (not case sensitive) one of "ATTACK", "PATROL", "REINFORCE", "CONVOY", "AIRSTRIKE" more to add
*   _side : SIDE; the side of the AI forces to send
*   _arguments : ARRAY; any further argument needed for the operation
+        -here should be some manual for each _type
*/

if(!serverInitDone) then
{
  diag_log "CreateAIAction: Waiting for server init to be completed!";
  waitUntil {sleep 1; serverInitDone};
};

if(isNil "_destination") exitWith {diag_log "CreateAIAction: No destination given for AI Action"};
_acceptedTypes = ["attack", "patrol", "reinforce", "convoy", "airstrike"];
if(isNil "_type" || {!((toLower _type) in _acceptedTypes)}) exitWith {diag_log "CreateAIAction: Type is not in the accepted types"};
if(isNil "_side" || {!(_side == Occupants || _side == Invaders)}) exitWith {diag_log "CreateAIAction: Can only create AI for Inv and Occ"};

_convoyID = round (random 100);
_IDinUse = server getVariable [str _convoyID, false];
sleep 0.1;
while {_IDinUse} do
{
  _convoyID = round (random 100);
  _IDinUse = server getVariable [str _convoyID, false];
};
server setVariable [str _convoyID, true, true];

_type = toLower _type;
_isMarker = _destination isEqualType "";
_targetString = if(_isMarker) then {_destination} else {str _destination};
diag_log format ["CreateAIAction[%1]: Started creation of %2 action to %3", _convoyID, _type, _targetString];

_nearestMarker = if(_isMarker) then {_destination} else {[markersX,_destination] call BIS_fnc_nearestPosition};
if ([_nearestMarker,false] call A3A_fnc_fogCheck < 0.3) exitWith {diag_log format ["CreateAIAction[%1]: AI Action on %2 cancelled because of heavy fog", _convoyID, _targetString]};

_abort = false;
_attackDistance = distanceSPWN2;
if (_isMarker) then
{
  if(_destination in attackMrk) then {_abort = true};
  _destination = getMarkerPos _destination;
}
else
{
  if(count attackPos != 0) then
  {
    _nearestAttack = [attackPos, _destination] call BIS_fnc_nearestPosition;
    if ((_nearestAttack distance _destination) < _attackDistance) then {_abort = true;};
  }
  else
  {
    if(count attackMrk != 0) then
    {
      _nearestAttack = [attackMrk, _destination] call BIS_fnc_nearestPosition;
      if (getMarkerPos _nearestAttack distance _destination < _attackDistance) then {_abort = true};
    };
  };
};
if(_abort) exitWith {diag_log format ["CreateAIAction[%1]: Aborting creation of AI action because, there is already a action close by!", _convoyID]};

_destinationPos = if(_destination isEqualType "") then {getMarkerPos _destination} else {_destination};
_originPos = [];
_origin = "";
_units = [];
_vehicleCount = 0;
_cargoCount = 0;
if(_type == "patrol") then
{

};
if(_type == "reinforce") then
{
  //Should outpost are able to reinforce to?
  _arguments params [["_small", true]];
  _airport = [_destination, _side] call A3A_fnc_findAirportForAirstrike;
  if(_airport != "") then
  {
    _land = if ((getMarkerPos _airport) distance _destinationPos > distanceForLandAttack) then {false} else {true};
    _typeGroup = if (_side == Occupants) then {if (_small) then {selectRandom groupsNATOmid} else {selectRandom groupsNATOSquad}} else {if (_small) then {selectRandom groupsCSATmid} else {selectRandom groupsCSATSquad}};

    _typeVeh = "";
    if (_land) then
    {
    	if (_side == Occupants) then {_typeVeh = selectRandom vehNATOTrucks} else {_typeVeh = selectRandom vehCSATTrucks};
    }
    else
    {
    	_vehPool = if (_side == Occupants) then {vehNATOTransportHelis} else {vehCSATTransportHelis};
    	if ((_small) and (count _vehPool > 1) and !hasIFA) then {_vehPool = _vehPool - [vehNATOPatrolHeli,vehCSATPatrolHeli]};
    	_typeVeh = selectRandom _vehPool;
    };
    _origin = _airport;
    _originPos = getMarkerPos _airport;
    _units pushBack [_typeVeh, _typeGroup];
    _vehicleCount = 1;
    _cargoCount = (count _typeGroup);
  }
  else
  {
    diag_log format ["CreateAIAction[%1]: Reinforcement aborted as no airport is available!", _convoyID];
    _abort = true;
  };
};
if(_type == "attack") then
{

};
if(_type == "airstrike") then
{
  _airport = [_destination, _side] call A3A_fnc_findAirportForAirstrike;
  if(_airport != "") then
  {
    _friendlies = if (_side == Occupants) then
    {
      allUnits select
      {
        (alive _x) &&
        {((side (group _x) == _side) || (side (group _x) == civilian)) &&
        {_x distance _destinationPos < 200}}
      };
    }
    else
    {
      allUnits select
      {
        (side (group _x) == _side) &&
        {(_x distance _destinationPos < 100) &&
        {[_x] call A3A_fnc_canFight}}
      };
    };
    //NATO accepts 2 casulties, CSAT does not really care
    if((_side == Occupants && {count _friendlies < 3}) || {_side == Invaders && {count _friendlies < 8}}) then
    {
      _plane = if (_side == Occupants) then {vehNATOPlane} else {vehCSATPlane};
    	if ([_plane] call A3A_fnc_vehAvailable) then
    	{
        _bombType = "";
        if(count _arguments != 0) then
        {
          _bombType = _arguments select 0;
        }
        else
        {
          _distanceSpawn2 = distanceSPWN2;
          _enemies = allUnits select
          {
            (alive _x) &&
            {(_x distance _destinationPos < _distanceSpawn2) &&
            {(side (group _x) != _side) and (side (group _x) != civilian)}}
          };
          if(isNil "napalmEnabled") then
          {
            //This seems to be a merge bug
            diag_log "CreateAIAction: napalmEnabled does not contains a value, assuming false!";
            napalmEnabled = false;
          };
          _bombType = if (napalmEnabled) then {"NAPALM"} else {"CLUSTER"};
    			{
    			  if (vehicle _x isKindOf "Tank") then
    				{
    				   _bombType = "HE" //Why should it attack tanks with HE?? TODO find better solution
    				}
    			  else
    				{
    				  if (vehicle _x != _x) then
    					{
    					  if !(vehicle _x isKindOf "StaticWeapon") then {_bombType = "CLUSTER"}; //TODO test if vehicle _x isKindOf Static is not also vehicle _x != _x
    					};
    				};
    			  if (_bombTypeX == "HE") exitWith {};
    			} forEach _enemies;
        };
        if (!_isMarker) then {airstrike pushBack _destinationPos};
        diag_log format ["CreateAIAction[%1]: Selected airstrike of bombType %2 from %3",_convoyID, _bombType, _airport];
        _origin = _airport;
        _originPos = getMarkerPos _airport;
        _units pushBack [_plane, []];
        _vehicleCount = 1;
        _cargoCount = 0;
      }
      else
      {
        diag_log format ["CreateAIAction[%1]: Aborting airstrike as the airplane is currently not available", _convoyID];
        _abort = true;
      };
    }
    else
    {
      diag_log format ["CreateAIAction[%1]: Aborting airstrike, cause there are too many friendly units in the area", _convoyID];
      _abort = true;
    };
  }
  else
  {
    diag_log format ["CreateAIAction[%1]: Aborting airstrike due to no avialable airport", _convoyID];
    _abort = true;
  };

};
if(_type == "convoy") then
{
  _isHeavy = if (random 10 < tierWar) then {true} else {false};
  _isEasy = if (!(_isHeavy) && {_sideX == Occupants && {random 10 >= tierWar}}) then {true} else {false};
  _origin = [_destination] call A3A_fnc_findBaseForConvoy;
  if(!(_origin isEqualTo "")) then
  {
    _typeConvoy = [];
    if ((_destination in airportsX) or (_destination in outposts)) then
    {
    	_typeConvoy = ["Ammunition","Armor"];
    	if (_destination in outposts) then
      {
        //That doesn't make sense, or am I wrong? Can someone double check this logic?
        if (((count (garrison getVariable [_destination,0]))/2) >= [_destinationX] call A3A_fnc_garrisonSize) then
        {
          _typeConvoy pushBack "Reinforcements";
        };
      };
    }
    else
    {
    	if (_destination in citiesX) then
    	{
        _typeConvoy = ["Supplies"];
    	}
    	else
    	{
    		if ((_destinationX in resourcesX) or (_destinationX in factories)) then
        {
          _typeConvoy = ["Money"];
        }
        else
        {
          _typeConvoy = ["Prisoners"];
        };
        //Same here, not sure about it
    		if (((count (garrison getVariable [_destinationX,0]))/2) >= [_destinationX] call A3A_fnc_garrisonSize) then
        {
          _typeConvoy pushBack "Reinforcements"
        };
    	};
  	};
    _selectedType = selectRandom _typeConvoy;

    private ["_timeLimit", "_dateLimitNum", "_displayTime", "_nameDest", "_nameOrigin" ,"_timeToFinish", "_dateFinal"];
    //The time the convoy will wait before starting
    _timeLimit = if (_isHeavy) then {0} else {round random 10};// timeX for the convoy to come out, we should put a random round 15

    _timeToFinish = 120;
    _dateTemp = date;
    _dateFinal = [_dateTemp select 0, _dateTemp select 1, _dateTemp select 2, _dateTemp select 3, (_dateTemp select 4) + _timeToFinish];
    _dateLimit = [_dateTemp select 0, _dateTemp select 1, _dateTemp select 2, _dateTemp select 3, (_dateTemp select 4) + _timeLimit];
    _dateLimitNum = dateToNumber _dateLimit;
    _dateLimit = numberToDate [_dateTemp select 0, _dateLimitNum];//converts datenumber back to date array so that time formats correctly when put through the function
    _displayTime = [_dateLimit] call A3A_fnc_dateToTimeString;//Converts the time portion of the date array to a string for clarity in hints

    _nameDest = [_destination] call A3A_fnc_localizar;
    _nameOrigin = [_origin] call A3A_fnc_localizar;
    [_origin, 30] call A3A_fnc_addTimeForIdle;

    private ["_text", "_taskState", "_taskTitle", "_taskIcon", "_taskState1", "_typeVehEsc", "_typeVehObj"];

    _text = "";
    _taskState = "CREATED";
    _taskTitle = "";
    _taskIcon = "";
    _taskState1 = "CREATED";

    _typeVehEsc = "";
    _typeVehObj = "";

    switch (_selectedType) do
    {
    	case "Ammunition":
    	{
    		_text = format ["A convoy from %1 is about to depart at %2. It will provide ammunition to %3. Try to intercept it. Steal or destroy that truck before it reaches it's destination.",_nameOrigin,_displayTime,_nameDest];
    		_taskTitle = "Ammo Convoy";
    		_taskIcon = "rearm";
    		_typeVehObj = if (_sideX == Occupants) then {vehNATOAmmoTruck} else {vehCSATAmmoTruck};
    	};
    	case "Armor":
    	{
    		_text = format ["A convoy from %1 is about to depart at %2. It will reinforce %3 with armored vehicles. Try to intercept it. Steal or destroy that thing before it reaches it's destination.",_nameOrigin,_displayTime,_nameDest];
    		_taskTitle = "Armored Convoy";
    		_taskIcon = "Destroy";
    		_typeVehObj = if (_sideX == Occupants) then {vehNATOAA} else {vehCSATAA};
    	};
    	case "Prisoners":
    	{
    		_text = format ["A group os POW's is being transported from %1 to %3, and it's about to depart at %2. Try to intercept it. Kill or capture the truck driver to make them join you and bring them to HQ. Alive if possible.",_nameOrigin,_displayTime,_nameDest];
    		_taskTitle = "Prisoner Convoy";
    		_taskIcon = "run";
    		_typeVehObj = if (_sideX == Occupants) then {selectRandom vehNATOTrucks} else {selectRandom vehCSATTrucks};
    	};
    	case "Reinforcements":
    	{
    		_text = format ["Reinforcements are being sent from %1 to %3 in a convoy, and it's about to depart at %2. Try to intercept and kill all the troops and vehicle objective.",_nameOrigin,_displayTime,_nameDest];
    		_taskTitle = "Reinforcements Convoy";
    		_taskIcon = "run";
    		_typeVehObj = if (_sideX == Occupants) then {selectRandom vehNATOTrucks} else {selectRandom vehCSATTrucks};
    	};
    	case "Money":
    	{
    		_text = format ["A truck plenty of money is being moved from %1 to %3, and it's about to depart at %2. Steal that truck and bring it to HQ. Those funds will be very welcome.",_nameOrigin,_displayTime,_nameDest];
    		_taskTitle = "Money Convoy";
    		_taskIcon = "move";
    		_typeVehObj = "C_Van_01_box_F";
    	};
    	case "Supplies":
    	{
    		_text = format ["A truck with medical supplies destination %3 it's about to depart at %2 from %1. Steal that truck bring it to %3 and let people in there know it is %4 who's giving those supplies.",_nameOrigin,_displayTime,_nameDest,nameTeamPlayer];
    		_taskTitle = "Supply Convoy";
    		_taskIcon = "heal";
    		_typeVehObj = "C_Van_01_box_F";
    	};
      default
      {
        diag_log format ["CreateAIAction[%1]: Aborting convoy, selected type not found, type was %2", _convoyID, _selectedType];
        _abort = true;
      };
    };
    if(!_abort) then
    {
      [[teamPlayer,civilian],"CONVOY",[_text,_taskTitle,_destination], _destinationPos,false,0,true,_taskIcon,true] call BIS_fnc_taskCreate;
      [[_side],"CONVOY1",[format ["A convoy from %1 to %3, it's about to depart at %2. Protect it from any possible attack.",_nameOrigin,_displayTime,_nameDest],"Protect Convoy",_destination],_destinationPos,false,0,true,"run",true] call BIS_fnc_taskCreate;
      missionsX pushBack ["CONVOY","CREATED"]; publicVariable "missionsX";
      sleep (_timeLimit * 60);

      //Creating convoy lead vehicle
      _typeVehX = if (_sideX == Occupants) then {if (!_isEasy) then {selectRandom vehNATOLightArmed} else {vehPoliceCar}} else {selectRandom vehCSATLightArmed};
      _units pushBack [_typeVehX,[]];
      _vehicleCount = _vehicleCount + 1;

    };
  }
  else
  {
    diag_log format ["CreateAIAction[%1]: Aborting convoy, as no base is available to send a convoy", _convoyID];
    _abort = true;
  };
};

if(_abort) exitWith {};

_target = if(_destination isEqualType "") then {name _destination} else {str _destination};
diag_log format ["CreateAIAction[%1]: Created AI action to %2 from %3 to %4 with %5 vehicles and %6 units", _convoyID, _type, _origin, _targetString, _vehicleCount , _cargoCount];

[_convoyID, _units, _originPos, _destinationPos, _type, _side] spawn A3A_fnc_createConvoy;