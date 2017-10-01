#!/usr/bin/awk -f

#Helper functions to trim strings
function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
function rtrim(s) { sub(/[ \t\r\n]+$/, "", s); return s }
function trim(s)  { return rtrim(ltrim(s)); }

function getvalue(v, count) {
    value = v; #"";
	for (i=1; i <= count; i++) {
		value = value " " $i;
	}
	return value;
}
#Estimate Types (1=AQH, 2=Cume, 3=Exclusive Cume)
function getEstimateType(row) {
	return substr(row, 14, 1);
}
#Daypart ID (1= Mon-Fri 5AM-6AM, 84=Mon-Sun 6A-Mid)
function getDayPartID(row) {
	return substr(row, 15, 4);
}
function getReportIDPeriod(row) {
	return substr(row, 4, 6);
}
#Audience Characteristic, ex : Males 18-24
function getAudienceChar(row) {
	return substr(row, 20,6);
}
#Build an array of data containing Audience Characteristics
#such as Boys 6-11.
function updateAudienceCharacteristics(acd, row) {
	acd[substr(row, 4, 6)] = substr(row, 10, 50);
}
function getDayPartTimes(daypart) {
    split(daypart, parts, " " );
	i = match(parts[2],/([0-9][0-9]?)/);
	h[1] = substr(parts[2],i,RLENGTH);
	i = match(parts[2],/\-([0-9][0-9]?)/);
	h[2] = substr(parts[2],i+1,RLENGTH-1);
	return h;
	
}
#Update an array of daypart data. Holds the ID & daypart name. ex : Morning 6-11AM
function updateDaypartData(dpd, row) {
	daypart = substr(row, 8 ,30);
    h = getDayPartTimes(daypart);
	if ((h[2] - h[1]) == 1){
		dpd[substr(row,4,4)] = substr(row, 8, 30);
	}
}
function getAudienceCharacteristic(row) {
	return substr(row, 10, 50);
}
function getStationID(row) {
	return substr(row, 28, 6);
}
function updateArbitronMarketData(mkd, row) {
	mkd[substr(row, 10, 3)] = substr(row, 77, 32);
}
#Update an array of station data. ex: KISS-FM
function updateStationData(std, row) {
	std[substr(row, 16, 6)] = substr(row, 22, 30);
}

function summarize() {
	for (keys in dpTotals) {
		split(keys, ids, SUBSEP);
		print trim(mkd[ids[1]]) ","  trim(std[ids[2]]) "," trim(dpd[ids[3]]) "," trim(acd[ids[4]]) "," dpTotals[keys] >  ("data.csv");
	}	
}
function getArbitronMarketCode(row) {
	return substr(row,10,3);
}
function getProgramStationList(file) {
	w=k=0;
	#Split the lists in two so that we only
	#search half the list at a time
	while ((getline line < file) > 0) {
		if (substr(line, 0, 1) == "K") {
			klist[line] = 1;
		}
		else
			wlist[line] = 1;
	}
}
function getProgramStationInfo(station) {
	var = "";
	for (var in klist) {
		if (var ~ station) {
			break;
		}
	}	

    return var;
}
function getProgramTime(program) {
	i = match(program, /[1-9][1-9]?/);
	t[1] = substr(program,i, RLENGTH);
	i = match(program, /-([1-9][1-9]?)/);
	t[2] = substr(program,i+1, RLENGTH-1);
	return t;
}
BEGIN {count = 0; 
	   acd[0] = ""; 
       dpd[0] = "";
       std[0] = ""; 
       dpTotals[0] =""; 
       mkd[0] = ""; 
       programList[0] = ""; 
	   klist[0] = "";
       wlist[0] = "";
	   programFile = "rlb.csv";
	   TOTAL_RECORD_MARKER = "8999999"; 
	   getProgramStationList(programFile);
	   print "{"}
{ 
  if ($1 ~ /A$/)
	updateArbitronMarketData(mkd, $0);
  if ($1 ~ /J$/) 
	updateStationData(std, $0);
  if ($1 ~ /S$/) {
	updateDaypartData(dpd, $0);
  } 
  if ($1 ~ /D$/) {
	updateAudienceCharacteristics(acd, $0);
  }
  # V records (i.e. rows) contain AQH values
  if ($1 ~ /V$/) {
	rpid = getReportIDPeriod($0);
	dpid = getDayPartID($0);
	acid = getAudienceChar($0);
	sid  = getStationID($0);
	mid  = getArbitronMarketCode($0);
	if ($6 != TOTAL_RECORD_MARKER) {
		#If there is info, then the station defined by sid is in the program
		info = getProgramStationInfo(trim(std[sid]));
		if (info != "") {
			pt = getProgramTime(info);
			if (pt != "") {
				dt = getDaypartTimes(dpd[dpid]);
				if (dt[1] >= pt[1] && dt[2] <= pt[2]) {	
					#is station time in program	
					dpTotals[mid,sid,dpid,acid] += $7
					rpid = dpid = acid = sid = mid = 0;
				}
			}
		}
	} else {
		getline;
	}
  } 
}
END {   summarize(); print "}";}	
