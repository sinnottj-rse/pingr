var csv = require('csv-parser'),
  fs = require('fs'),
  path = require('path'),
  async = require('async');

var FILENAMES = {
  demographics: 'demographics.dat',
  denominators: 'denominators.dat',
  diagnoses: 'diagnoses.dat',
  medications: 'medications.dat',
  events: 'impCodes.dat',
  indicators: 'indicator.dat',
  measurements: 'measures.dat',
  contacts: 'contacts.dat',
  patientActions: 'patActions.dat',
  orgActions: 'orgActions.dat',
  text: 'text.dat'
};

var IN_DIR = process.argv[2] || 'E:\\ImporterPINGR\\';
var OUT_DIR = process.argv[3] || 'data/';

//Load current data
//make sure opportunities is empty
var dataFile = { indicators: JSON.parse(fs.readFileSync(IN_DIR + 'existingIndicators.json', 'utf8') || "[]"), patients: {} };
var textFile = {
  pathways: {},
  measurements: {
    "eGFR": {
      "name": "eGFR",
      "unit": "ml/min/1.73m^2",
      "type": "line",
      "valueDecimals": 1
    },
    "ACR": {
      "name": "ACR",
      "unit": "μg/mg",
      "type": "line",
      "valueDecimals": 0
    },
    "BP": {
      "name": "BP",
      "unit": "mmHg",
      "type": "errorbar"
    }
  }
};

var messages = [];

var readCsvAsync = function(input, callback) {
  var obj = [];
  fs.createReadStream(input.file)
    .pipe(csv({ separator: '\t', headers: input.headers }))
    .on('data', function(data) {
      var o = {};
      for (var i = 0; i < input.headers.length; i++) {
        o[input.headers[i]] = data[input.headers[i]];
      }
      obj.push(o);
    })
    .on('err', function(err) { callback(err); })
    .on('end', function() { callback(null, obj); });
};

var indicators = dataFile.indicators;
var patients = dataFile.patients;

var assign = function(obj, prop, value) {
  if (typeof prop === "string")
    prop = prop.split(".");

  if (prop.length > 1) {
    var e = prop.shift();
    assign(obj[e] =
      Object.prototype.toString.call(obj[e]) === "[object Object]" ? obj[e] : {},
      prop,
      value);
  } else
    obj[prop[0]] = value;
};

//Load new text


//read existing indicators as dumped from mongo
fs.readFileSync(IN_DIR + FILENAMES.text, 'utf8').split("\n").forEach(function(line) {
  var els = line.trim("\r").split("\t");
  if (els.length < 5) {
    if (els[0].replace(/[^a-zA-Z0-9]/g, "").length > 0) messages.push("The text.dat file contains a row with no TAB character: " + els[0]);
    return;
  }
  var pathway = els[0],
    stage = els[1],
    standard = els[2],
    key = els[3],
    val = els[4];
  if (!textFile.pathways[pathway]) textFile.pathways[pathway] = {};
  if (!textFile.pathways[pathway][stage]) textFile.pathways[pathway][stage] = { standards: {} };
  if (!textFile.pathways[pathway][stage].standards[standard]) textFile.pathways[pathway][stage].standards[standard] = {};
  assign(textFile.pathways[pathway][stage].standards[standard], key, val);
});

var tempDates = [];
async.series([
    function(callback) {
      console.log("1 series");
      fs.createReadStream(IN_DIR + FILENAMES.indicators)
        .pipe(
          csv({
            separator: '\t',
            headers: ['indicatorid', 'gpcode', 'date', 'numerator', 'denominator', 'target', 'benchmark']
          })
        )
        .on('data', function(data) {
          if (data.date) {

            var i = indicators.filter(function(v) {
              return v.id === data.indicatorid && v.practiceId === data.gpcode;
            })[0];

            var pathway = data.indicatorid.split('.')[0];
            var stage = data.indicatorid.split('.')[1];
            var standard = data.indicatorid.split('.')[2];

            var indText = textFile.pathways[pathway][stage].standards[standard];
            var oppText = indText.opportunities;

            if (!i) {
              i = {
                id: data.indicatorid,
                practiceId: data.gpcode,
                measurementId: indText.valueId,
                benchmark: data.benchmark,
                displayDate: indText.dateORvalue === "date",
                name: indText.name,
                description: indText.description,
                values: [["x"], ["numerator"], ["denominator"], ["target"]],
                opportunities: []
              };
              indicators.push(i);
            } else {
              i.benchmark = data.benchmark;
            }

            var dtt = data.date.replace(/[^0-9-]/g, "");
            //replace if already there
            var dttIdx = i.values[0].indexOf(dtt);
            if (dttIdx === -1) {
              i.values[0].push(dtt);
              i.values[1].push(data.numerator);
              i.values[2].push(data.denominator);
              i.values[3].push(data.target);
            } else {
              i.values[1][dttIdx] = data.numerator;
              i.values[2][dttIdx] = data.denominator;
              i.values[3][dttIdx] = data.target;
            }

            //Sort them all..
            var temp = i.values[0].slice(1).map(function(v, idx) {
              return { a: v, b: i.values[1][idx + 1], c: i.values[2][idx + 1], d: i.values[3][idx + 1] };
            });
            //sort
            temp.sort(function(a, b) {
              return a.a === b.a ? 0 : (a.a < b.a ? -1 : 1);
            });

            //reassign
            temp.forEach(function(v, idx) {
              i.values[0][idx + 1] = v.a;
              i.values[1][idx + 1] = v.b;
              i.values[2][idx + 1] = v.c;
              i.values[3][idx + 1] = v.d;
            });
          }
        })
        .on('end', function() {
          /*tempDates.sort(function(a, b) {
            return new Date(a.date).getTime() - new Date(b.date).getTime();
          });
          tempDates.forEach(function(v) {
            i.values[0].push(v.date);
            i.values[1].push(v.num);
            i.values[2].push(v.den);
            i.values[3].push(v.target);
          });*/
          console.log("1 series done");
          callback(null);
        })
        .on('err', function(err) {
          console.log("1 series err");
          callback(err);
        });
    },

    function(callback) {
      console.log("2 series");
      async.map([
        { file: IN_DIR + FILENAMES.demographics, headers: ['patientId', 'nhsnumber', 'age', 'sex', 'gpcode'] },
        { file: IN_DIR + FILENAMES.diagnoses, headers: ['patientId', 'date', 'diag', 'cat'] },
        { file: IN_DIR + FILENAMES.medications, headers: ['patientId', 'date', 'type', 'family', 'mg', 'event'] },
        { file: IN_DIR + FILENAMES.measurements, headers: ['patientId', 'date', 'thing', 'value'] },
        { file: IN_DIR + FILENAMES.events, headers: ['patientId', 'date', 'event'] },
        { file: IN_DIR + FILENAMES.contacts, headers: ['patientId', 'date', 'contact'] },
        { file: IN_DIR + FILENAMES.denominators, headers: ['patientId', 'indicatorId'] }
      ], readCsvAsync, function(err, results) {
        console.log("all files loaded");
        if (err) {
          return callback(err);
        }
        var temp = {};
        //age, sex
        results[0].forEach(function(v) {
          temp[+v.patientId] = {};
          if (!patients[+v.patientId]) {
            patients[+v.patientId] = { patientId: +v.patientId, characteristics: { nhs: v.nhsnumber, age: v.age, sex: v.sex, practiceId: v.gpcode } };
            patients[+v.patientId].conditions = [];
            patients[+v.patientId].events = [];
            patients[+v.patientId].contacts = [];
            patients[+v.patientId].measurements = [];
            patients[+v.patientId].standards = [];
            patients[+v.patientId].medications = [];
            patients[+v.patientId].actions = [];
          }
        });
        results[0] = null;
        console.log("age, sex etc. done");
        //diagnoses
        results[1].forEach(function(v) {
          if (!temp[+v.patientId]) {
            console.log("Diagnosis for unknown patient: " + v.patientId);
            return;
          }
          if (!temp[+v.patientId].diag) temp[+v.patientId].diag = {};
          if (!temp[+v.patientId].diag[v.diag]) temp[+v.patientId].diag[v.diag] = [];
          temp[+v.patientId].diag[v.diag].push({ date: new Date(v.date).getTime(), cat: v.cat });
        });

        Object.keys(temp).forEach(function(p) {
          if (temp[p].diag && patients[p].conditions.filter(function(v) {
              return Object.keys(temp[p].diag).indexOf(v.name) > -1;
            }).length === 0) {
            Object.keys(temp[p].diag).forEach(function(d) {
              temp[p].diag[d].sort(function(a, b) {
                return a.date - b.date;
              });
              var intervals = [];
              var last = temp[p].diag[d].reduce(function(prev, cur) {
                var end = new Date(cur.date);
                end.setDate(end.getDate() - 1);
                intervals.push({
                  from: prev.date,
                  to: end.getTime(),
                  label: prev.cat || ""
                });
                return cur;
              });
              intervals.push({
                from: last.date,
                to: new Date().getTime(),
                label: last.cat
              });
              patients[p].conditions.push({
                name: d,
                intervals: intervals
              });
            });
          }
        });
        results[1] = null;
        console.log("diagnoses done");
        //medications
        results[2].forEach(function(v) {
          if (!temp[+v.patientId]) {
            console.log("Medication for unknown patient: " + v.patientId);
            return;
          }
          if (!temp[+v.patientId].meds) temp[+v.patientId].meds = {};
          if (!temp[+v.patientId].meds[v.type]) temp[+v.patientId].meds[v.type] = [];
          temp[+v.patientId].meds[v.type].push({ date: new Date(v.date).getTime(), type: v.type, family: v.family, mg: v.mg, event: v.event });
        });

        Object.keys(temp).forEach(function(p) {
          if (temp[p].meds && patients[p].medications.filter(function(v) {
              return Object.keys(temp[p].meds).indexOf(v.name) > -1;
            }).length === 0) {
            Object.keys(temp[p].meds).forEach(function(d) {
              temp[p].meds[d].sort(function(a, b) {
                return a.date - b.date;
              });
              var intervals = [];
              var last = temp[p].meds[d].reduce(function(prev, cur) {
                var end = new Date(cur.date);
                end.setDate(end.getDate() - 1);
                if (prev) {
                  intervals.push({
                    from: prev.date,
                    to: end.getTime(),
                    label: prev.mg + "mg" || ""
                  });
                }
                return d.event === "STOPPED" ? null : cur;
              });
              if (last) {
                intervals.push({
                  from: last.date,
                  to: new Date().getTime(),
                  label: last.mg + "mg" || ""
                });
              }
              patients[p].medications.push({
                name: d,
                intervals: intervals
              });
            });
          }
        });
        results[2] = null;
        console.log("medications done");

        //measurements
        results[3].forEach(function(v) {
          if (!temp[+v.patientId]) {
            console.log("Measure for unknown patient: " + v.patientId);
            return;
          }
          if (!temp[+v.patientId].meas) temp[+v.patientId].meas = {};
          if (["SBP", "DBP"].indexOf(v.thing) > -1) {
            if (!temp[+v.patientId].meas.BP) temp[+v.patientId].meas.BP = [];
            temp[+v.patientId].meas.BP.push({ date: new Date(v.date).getTime(), value: v.value, thing: v.thing });
          } else if (v.thing === "BP") {
            return;
          } else {
            if (!temp[+v.patientId].meas[v.thing]) temp[+v.patientId].meas[v.thing] = [];
            temp[+v.patientId].meas[v.thing].push({ date: new Date(v.date).getTime(), value: v.value });
          }

        });

        var tempbp = {};

        Object.keys(temp).forEach(function(p) {
          if (temp[p].meas && patients[p].measurements.filter(function(v) {
              return Object.keys(temp[p].meas).indexOf(v.id) > -1;
            }).length === 0) {
            Object.keys(temp[p].meas).forEach(function(d) {
              temp[p].meas[d].sort(function(a, b) {
                return a.date - b.date;
              });
              var mData = [];
              if (d === "BP") {
                var lastdate;
                var sbp, dbp;
                for (var i = 0; i < temp[p].meas[d].length; i++) {
                  if (lastdate === temp[p].meas[d][i].date) {
                    if (temp[p].meas[d][i].thing === "SBP") {
                      sbp = +temp[p].meas[d][i].value;
                    } else {
                      dbp = +temp[p].meas[d][i].value;
                    }
                    if (sbp && dbp) {
                      mData.push([lastdate, sbp, dbp]);
                      sbp = null;
                      dbp = null;
                      lastdate = null;
                    }
                  } else {
                    sbp = null;
                    dbp = null;
                    lastdate = temp[p].meas[d][i].date;
                    if (temp[p].meas[d][i].thing === "SBP") {
                      sbp = temp[p].meas[d][i].value;
                    } else {
                      dbp = temp[p].meas[d][i].value;
                    }
                  }
                }

                patients[p].measurements.push({
                  "id": d,
                  "name": "BP",
                  "data": mData,
                  "unit": "mmHg",
                  "type": "errorbar",
                  "valueDecimals": 0
                });
              } else {
                temp[p].meas[d].forEach(function(v) {
                  mData.push([v.date, +v.value]);
                });

                patients[p].measurements.push({
                  "id": d,
                  "name": textFile.measurements[d].name,
                  "data": mData,
                  "unit": textFile.measurements[d].unit,
                  "type": textFile.measurements[d].type,
                  "valueDecimals": textFile.measurements[d].valueDecimals
                });
              }
            });
          }
        });
        results[3] = null;
        console.log("measurements done");


        //events
        results[4].forEach(function(v) {
          if (!patients[+v.patientId]) console.log("Event without patient:" + JSON.stringify(v));
          else {
            patients[+v.patientId].events.push({
              name: v.event,
              time: new Date(v.date).getTime(),
              task: 1
            });
          }
        });
        results[4] = null;
        console.log("events done");

        //contacts
        results[5].forEach(function(v) {
          if (!temp[+v.patientId]) {
            console.log("Contact for unknown patient: " + v.patientId);
            return;
          }
          patients[+v.patientId].contacts.push({
            name: v.contact,
            time: new Date(v.date).getTime(),
            task: 2
          });
        });
        results[5] = null;
        console.log("contacts done");

        //indicators
        results[6].forEach(function(v) {
          if (!temp[+v.patientId]) {
            console.log("Indicator for unknown patient: " + v.patientId);
            return;
          }
          var pathway = v.indicatorId.split('.')[0];
          var stage = v.indicatorId.split('.')[1];
          var standard = v.indicatorId.split('.')[2];

          var indText = textFile.pathways[pathway][stage].standards[standard];
          patients[+v.patientId].standards.push({ display: indText.tabText, targetMet: true });
        });
        results[6] = null;
        console.log("indicators done");

        indicators.forEach(function(v) {
          v.opportunities.forEach(function(vv, ix) {
            v.opportunities[ix].patients = [];
          });
        });

        fs.createReadStream(IN_DIR + FILENAMES.patientActions)
          .pipe(
            csv({
              separator: '\t',
              headers: ['patientId', 'indicatorId', 'opportunity', 'actionId', 'reasonNumber', 'priority', 'short', 'reason']
            })
          )
          .on('data', function(data) {
            var pathway = data.indicatorId.split('.')[0];
            var stage = data.indicatorId.split('.')[1];
            var standard = data.indicatorId.split('.')[2];

            var indText = textFile.pathways[pathway][stage].standards[standard];
            var oppText = indText.opportunities;

            if (!patients[+data.patientId]) {
              console.log("Action for unknown patient: " + v.patientId);
              return;
            }

            if (patients[+data.patientId].actions.filter(function(v) {
                return v.id === data.actionId;
              }).length === 0) {
              patients[+data.patientId].actions.push({
                id: data.actionId,
                indicatorId: data.indicatorId,
                short: data.short,
                reason: data.reason,
                priority: data.priority
              });
            }

            var patientsStandard = patients[+data.patientId].standards.filter(function(v) {
              return v.display === indText.tabText;
            });
            if (patientsStandard.length === 0) {
              console.log("patient: " + data.patientId + " --numerator patient not appearing in denominator e.g. they appear in patActions but not in the denominator table");
              patients[+data.patientId].standards.push({ display: indText.tabText, targetMet: false });
            } else if (patientsStandard.length > 1) console.log("patient: " + data.patientId + " --numerator patient appearing more than once in the denominator e.g. they appear in the denominator table more than once");
            else patientsStandard[0].targetMet = false;

            var i = indicators.filter(function(v) {
              return v.id === data.indicatorId && v.practiceId === patients[+data.patientId].characteristics.practiceId;
            })[0];

            if (!i) {
              console.log("no indicator for" + JSON.stringify(data));
              return;
            }
            if (!i.opportunities) i.opportunities = [];

            var opp = i.opportunities.filter(function(v) {
              return v.id === data.opportunity;
            })[0];
            if (!opp) {
              if (!oppText[data.opportunity]) oppText[data.opportunity] = {};
              console.log(data.opportunity);
              opp = { id: data.opportunity, name: oppText[data.opportunity].name, positionInBarChart: oppText[data.opportunity].positionInBarChart, description: oppText[data.opportunity].description, patients: [] };
              i.opportunities.push(opp);
              i.opportunities.sort(function(a, b) {
                return a.positionInBarChart - b.positionInBarChart;
              });
            }
            if (opp.patients.indexOf(+data.patientId) === -1) opp.patients.push(+data.patientId);
          })
          .on('end', function() {

            console.log("opps done");

            //now for the orgactions
            fs.createReadStream(IN_DIR + FILENAMES.orgActions)
              .pipe(
                csv({
                  separator: '\t',
                  //headers: ['indicatorId', 'practiceId', 'proportion', 'actionId', 'priority', 'actionText', 'supportingText']
                  headers: ['indicatorId', 'proportion', 'actionText', 'supportingText']
                })
              ) //NEED practiceId, actionId and priority
              .on('data', function(data) {

                var i = indicators.filter(function(v) {
                  return v.id === data.indicatorId && v.practiceId === data.practiceId;
                })[0];

                i.actions.push({
                  id: data.actionId || "default_to_change",
                  indicatorId: data.indicatorId,
                  short: data.actionText,
                  reason: data.supportingText,
                  priority: data.priority || 1
                });
              })
              .on('end', function() {
                //Deduplicate contacts
                /*console.log("Removing duplicate contacts...");
                Object.keys(patients).forEach(function(pid) {
                  var item, tempContact = {},
                    i, n;
                  for (i = 0, n = patients[pid].contacts.length; i < n; i++) {
                    item = patients[pid].contacts[i];
                    tempContact[item.name + item.time] = item;
                  }
                  i = 0;
                  var nonDuplicatedArray = [];
                  for (item in tempContact) {
                    nonDuplicatedArray[i++] = tempContact[item];
                  }
                  patients[pid].contacts = nonDuplicatedArray;
                  console.log(pid + ": " + n + " contacts reduced to " + patients[pid].contacts.length);
                });
                console.log("Duplicate contacts removed.");*/

                dataFile.text = textFile;


                fs.writeFileSync(OUT_DIR + 'indicators.json', JSON.stringify(dataFile.indicators, null, 2));


                dataFile.patients = Object.keys(dataFile.patients).map(function(v) {
                  return dataFile.patients[v];
                });

                var file = fs.createWriteStream(OUT_DIR + 'patients.json');
                file.on('error', function(err) { /* error handling */ });
                dataFile.patients.forEach(function(v) { file.write(JSON.stringify(v) + '\n'); });
                file.end();

                fs.writeFileSync(OUT_DIR + 'text.json', JSON.stringify([textFile], null, 2));

                if (messages.length > 0) {
                  console.log();
                  console.log("################");
                  console.log("## WARNING!!! ##");
                  console.log("################");
                  console.log();
                  console.log("The following errors were detected and should be investigated:");
                  console.log();
                  messages.forEach(function(msg) {
                    console.warn(msg);
                  });
                }
              });
          });
      });
    }],
  // optional callback
  function(err, results) {
    // results is now equal to ['one', 'two']
    if (err) {
      console.log(err);
    }
  }
);
