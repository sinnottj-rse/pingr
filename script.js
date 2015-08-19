/*jslint browser: true*/
/*jshint -W055 */
/*global $, c3, Mustache, ZeroClipboard, console, jsPDF, Bloodhound, bb, alert*/

/*
 * For each disease area there will be 4 stages: Diagnosis, Monitoring, Treatment and Exclusions.
 * Each stage gets a single panel on the front screen.
 * Clicking on a panel takes you to a screen specific to that stage, but similar in layour and content
 *  to all the others.
 */

(function () {
  'use strict';

  var location = window.history.location || window.location;
	/*******************************
	 *** Define local properties ***
	 *******************************/
	var local= {
		"charts" : {},
		"data" : {},
    "elements" : {},
    "actionPlan": {},
		"categories" : {
			"diagnosis": {"name": "diagnosis", "display": "Diagnosis"},
			"monitoring": {"name": "monitoring", "display": "Monitoring"},
			"treatment": {"name": "treatment", "display": "Control"},
			"exclusions": {"name": "exclusions", "display": "Exclusions"}
		},
		"page" : "",
		"pathwayId" : "bp",
    "colors" : ['#1f77b4', '#ff7f0e', '#2ca02c', '#d62728', '#9467bd', '#8c564b', '#e377c2', '#7f7f7f', '#bcbd22', '#17becf'],
    "diseases" : [],
    "pathwayNames" : {},
    "monitored" : {"bp" : "Blood Pressure", "asthma" : "Peak Expiratory Flow"},
    "tmp" : null
	};

	var bottomLeftPanel, bottomRightPanel, topPanel, topLeftPanel, topRightPanel, midPanel, farLeftPanel, farRightPanel, monitoringPanel, treatmentPanel,
		diagnosisPanel,	exclusionPanel, patientsPanelTemplate, breakdownPanel, actionPlanPanel, patientList, patientListSimple, suggestedPlanTemplate,
		breakdownTableTemplate,	individualPanel, valueTrendPanel, medicationPanel, patientsPanel,	suggestedPlanTeam, adviceList, breakdownTable,
    patientInfo, teamTab, individualTab, actionPlanList;


  //Side panel, navigation, header bar and main page
  var showMainView = function(idx){
    //Set up navigation panel
    showSidePanel();
    showNavigation(local.diseases, idx, $('#main-dashboard'));

    showHeaderBarItems();

    //Show main dashboard page
    showPage('main-dashboard');
  };

  //Show the overview page for a disease
  var showOverview = function(disease){
    local.pathwayId = disease;

    showMainView(local.diseases.map(function(v){ return v.id; }).indexOf(disease));

    $('aside li ul li').removeClass('active');
    $('aside a[href="#main/' + disease + '"]:contains("Overview")').parent().addClass('active');

    updateTitle(local.data[local.pathwayId]["display-name"] + " - overview");

    //Show overview panels
    showOverviewPanels();
    showTeamActionPlanPanel(farRightPanel);
  };

  //Show the pathway stage for a disease
  var showPathwayStageView = function(disease, pathwayStage, standard){
    showMainView(local.diseases.map(function(v){ return v.id; }).indexOf(disease));

    $('aside li ul li').removeClass('active');
    var re = new RegExp(pathwayStage,"g");
    $('aside a').filter(function(){
      return this.href.match(re);
    }).parent().addClass('active');

    switchTo110Layout();

    if(!standard) {
      standard = Object.keys(local.data[disease][pathwayStage].standards)[0];
    }

    var panel = createPatientPanel(pathwayStage, standard);

    farLeftPanel.fadeOut(100, function(){
      $(this).html(panel);
      wireUpPatientPanel(pathwayStage, farLeftPanel, standard);
      populatePatientPanel(local.pathwayId, pathwayStage, standard, null);
      updateTitle(local.data[local.pathwayId][pathwayStage].pageTitle);
      $(this).fadeIn(100, function(){
        patientsPanel.parent().parent().parent().parent().removeClass('panel-default').addClass('panel-' + pathwayStage);
        farRightPanel.children(':first').removeClass('panel-default').addClass('panel-' + pathwayStage);
      })
    });
    farRightPanel.html("");
  };

  var showPathwayStageViewOk = function(disease, pathwayStage){
    showMainView(local.diseases.map(function(v){ return v.id; }).indexOf(disease));

    $('aside li ul li').removeClass('active');
    var re = new RegExp(pathwayStage,"g");
    $('aside a').filter(function(){
      return this.href.match(re);
    }).parent().addClass('active');

    switchTo110Layout();

    var panel = createPatientPanelOk(pathwayStage);

    farLeftPanel.fadeOut(100, function(){
      $(this).html(panel);
      wireUpPatientPanelOk(pathwayStage, farLeftPanel);
      populatePatientPanelOk(local.pathwayId, pathwayStage, null);
      updateTitle(local.data[local.pathwayId][pathwayStage].pageTitle);
      $(this).fadeIn(100, function(){
        patientsPanel.parent().parent().parent().parent().removeClass('panel-default').addClass('panel-' + pathwayStage);
        farRightPanel.children(':first').removeClass('panel-default').addClass('panel-' + pathwayStage);
      })
    });
    farRightPanel.html("");
  };

  //Show patient view within the pathway stage view
  var showPathwayStagePatientView = function(patientId, pathwayId, pathwayStage, isMultiple){
    local.patientId = patientId;

    //switchTo121Layout();
    switchTo110Layout();

    showIndividualPatientPanel(pathwayId, pathwayStage, patientId, isMultiple);
  };

  var showIndividualPatientPanel = function(pathwayId, pathwayStage, patientId, isMultiple){
    var panel = createPanel($('#patient-panel'), {"pathwayStage" : pathwayStage, "nhsNumber" : local.patLookup ? local.patLookup[patientId] : patientId, "patientId" : patientId, "isMultiple" : isMultiple});

    farRightPanel.html("");
    $('#temp-hidden').html(panel);

    var actionPlan = createIndividualActionPlanPanel(pathwayStage);
    $('#temp-hidden #patient-panel-right').html(actionPlan);

    var qualPanel = createQualStanPanel(pathwayId, pathwayStage, patientId, isMultiple);
    var trendPanel = createTestTrendPanel(pathwayId, pathwayStage, patientId);
    var medPanel = createMedicationPanel(pathwayStage, patientId);
    var multPanel = createPanel($('#pathway-panel'), {"multiple" : local.data.patients[patientId].breach.length>1,"pathways":local.data.patients[patientId].breach.map(function(val, i){val.name=local.pathwayNames[val.pathwayId]; val.checked = val.pathwayId===pathwayId; return val;})},{"radio":$('#pathway-panel-radio').html()});
    $('#temp-hidden #patient-panel-top').html(qualPanel);
    $('#temp-hidden #patient-panel-mid').html(multPanel);
    $('#temp-hidden #patient-panel-left').html("").append(trendPanel).append(medPanel);

    if(farRightPanel.is(':visible')) {
      farRightPanel.fadeOut(100, function(){
        $(this).html($('#temp-hidden').html());
          $('#temp-hidden').html("");
          wireUpIndividualActionPlanPanel(pathwayId, pathwayStage, patientId, isMultiple);
          wireUpQualStan(pathwayId, pathwayStage);
          drawTrendChart(patientId, pathwayId);
          if(local.data.patients[patientId].breach.length>1){
            $('input[name=pathwayradio]').off('change').on('change', function(){
              //find breach $(this).val() = asthma, bp etc.
              var value = $(this).val();
              var breach = local.data.patients[patientId].breach.filter(function(val){ return val.pathwayId === value})[0];
              showIndividualPatientPanel(breach.pathwayId, breach.pathwayStage, patientId,  false);
            });
          }
          $(this).fadeIn(100, function(){
        });
      });
    } else {
      farRightPanel.html($('#temp-hidden').html());
        $('#temp-hidden').html("");
        wireUpIndividualActionPlanPanel(pathwayId, pathwayStage, patientId, isMultiple);
        wireUpQualStan(pathwayId, pathwayStage);
        drawTrendChart(patientId, pathwayId);
        if(local.data.patients[patientId].breach.length>1){
          $('input[name=pathwayradio]').off('change').on('change', function(){
            //find breach $(this).val() = asthma, bp etc.
            var value = $(this).val();
            var breach = local.data.patients[patientId].breach.filter(function(val){ return val.pathwayId === value})[0];
            showIndividualPatientPanel(breach.pathwayId, breach.pathwayStage,patientId,  false);
          });
        }
        farRightPanel.fadeIn(100, function(){
      });
    }
  };

  //Show patient view from the all patient screen
  var showIndividualPatientView = function(patientId, pathwayId, pathwayStage, isMultiple){
    local.patientId = patientId;
    var panel = createPanel($('#patient-panel'), {"pathwayStage" : pathwayStage, "nhsNumber" : local.patLookup ? local.patLookup[patientId] : patientId, "patientId" : patientId, "isMultiple" : isMultiple});

    farRightPanel.html("");
    $('#temp-hidden').html(panel);

    //showIndividualActionPlanPanel($('#patient-panel-right'), pathwayId, pathwayStage, patientId, isMultiple);
    var actionPlan = createIndividualActionPlanPanel(pathwayStage);
    $('#temp-hidden #patient-panel-right').html(actionPlan);

    var qualPanel = createQualStanPanel(pathwayId, pathwayStage, patientId, isMultiple);
    var trendPanel = createTestTrendPanel(pathwayId, pathwayStage, patientId);
    var medPanel = createMedicationPanel(pathwayStage, patientId);
    var multPanel = createPanel($('#pathway-panel'), {"multiple" : local.data.patients[patientId].breach.length>1,"pathways":local.data.patients[patientId].breach.map(function(val, i){val.name=local.pathwayNames[val.pathwayId]; val.checked = val.pathwayId===pathwayId; return val;})},{"radio":$('#pathway-panel-radio').html()});
    $('#temp-hidden #patient-panel-top').html(qualPanel);
    $('#temp-hidden #patient-panel-mid').html(multPanel);
    $('#temp-hidden #patient-panel-left').html("").append(trendPanel).append(medPanel);

    if(farRightPanel.is(':visible')) {
      farRightPanel.fadeOut(100, function(){
        $(this).html($('#temp-hidden').html());
          $('#temp-hidden').html("");
          wireUpIndividualActionPlanPanel(pathwayId, pathwayStage, patientId, isMultiple);
          wireUpQualStan(pathwayId, pathwayStage);
          drawTrendChart(patientId, pathwayId);

          if(local.data.patients[patientId].breach.length>1){
            $('input[name=pathwayradio]').off('change').on('change', function(){
              //find breach $(this).val() = asthma, bp etc.
              var value = $(this).val();
              var breach = local.data.patients[patientId].breach.filter(function(val){ return val.pathwayId === value})[0];
              showIndividualPatientView(patientId, breach.pathwayId, breach.pathwayStage, false);
            });
          }

          $(this).fadeIn(100, function(){
        });
      });
    } else {
        farRightPanel.html($('#temp-hidden').html());
        $('#temp-hidden').html("");
        wireUpIndividualActionPlanPanel(pathwayId, pathwayStage, patientId, isMultiple);
        wireUpQualStan(pathwayId, pathwayStage);
        drawTrendChart(patientId, pathwayId);


        if(local.data.patients[patientId].breach.length>1){
          $('input[name=pathwayradio]').off('change').on('change', function(){
            //find breach $(this).val() = asthma, bp etc.
            var value = $(this).val();
            var breach = local.data.patients[patientId].breach.filter(function(val){ return val.pathwayId === value})[0];
            showIndividualPatientView(patientId, breach.pathwayId, breach.pathwayStage, false);
          });
        }

        farRightPanel.fadeIn(100, function(){
      });
    }
  };

  var showAllPatientView = function(patientId, reload){
    updateTitle("All patients");

    if(!patientId) local.pathwayId="";
    if(!patientId || reload) {

      showMainView(local.diseases.length);

      switchTo110Layout();
      hideAllPanels();

      showAllPatientPanel(farLeftPanel);
      populateAllPatientPanel();
    }

    if(patientId){
      showIndividualPatientView(patientId, local.data.patients[patientId].breach[0].pathwayId, local.data.patients[patientId].breach[0].pathwayStage, false);
    }
  };

  //id is either "team" or the patientId
  var recordFeedback = function(pathwayId, id, suggestion, reason, reasonText ){
    local.reason = {"reason":reason, "reasonText":reasonText};
    var obj = getObj();

    var item = {"pathwayId": pathwayId, "id": id, "val" : suggestion};
    if(reasonText !== "") item.reasonText = reasonText;
    if(reason !== "") item.reason = reason;
    obj.feedback.push(item);
    setObj(obj);
  };

  var recordEvent = function(pathwayId, id, name) {
    var obj = getObj();
    obj.events.push({"pathwayId": pathwayId, "id": id, "name": name, "date": new Date()});
    setObj(obj);
  };

  var recordPlan = function(id, text, pathwayId){
    if(!id) alert("PLAN");
    var obj = getObj();

    if(!obj.actions[id]) obj.actions[id] = {};
    var planId = Date.now()+"";
    obj.actions[id][planId] = {"text":text, "agree":null, "done":false, "pathwayId" : pathwayId, "history" : ["You added this on " + (new Date()).toDateString()]};

    setObj(obj);
    return planId;
  };

  var findPlan = function(obj, planId){
    for(var k in obj.actions){
      if(obj.actions[k][planId] && obj.actions[k][planId].text) return k;
    }
    return -1;
  };

  var editPlan = function(planId, text, done){
    var obj = getObj();
    var id = findPlan(obj, planId);
    if(text) obj.actions[id][planId].text = text;
    if(done===true || done===false) obj.actions[id][planId].done = done;
    setObj(obj);
  };

  var deletePlan = function(planId){
    var obj = getObj();
    var id = findPlan(obj, planId);
    delete obj.actions[id][planId];
    setObj(obj);
  };

  var listPlans = function(id, pathwayId){
    var obj = getObj(), arr = [];
    if(!id) return obj.actions;
    for(var prop in obj.actions[id]){
      obj.actions[id][prop].id = prop;
      if((!pathwayId || pathwayId === obj.actions[id][prop].pathwayId) && obj.actions[id][prop].text) arr.push(obj.actions[id][prop]);
    }
    return arr;
  };

  var getReason = function(id, actionId){
    var obj = getObj();

    if(obj.actions[id] && obj.actions[id][actionId]) return obj.actions[id][actionId].reason;
    return null;
  };

  var editAction = function(id, actionId, agree, done, reason){
    var obj = getObj(), log;
    if(!id) alert("ACTION TEAM/IND ID");
    if(!actionId) alert("ACTION ID");

    if(!obj.actions[id]) {
      obj.actions[id] = {};
    }


    if(agree) {
      log = "You agreed with this on " + (new Date()).toDateString();
    } else if(agree===false) {
      var reasonText = local.reason.reason === "" && local.reason.reasonText === "" ? " - no reason given" : " . You disagreed because you said: '" + local.reason.reason + "; " + local.reason.reasonText +".'";
      log = "You disagreed with this action on " + (new Date()).toDateString() + reasonText;
    }

    if(done) {
      log = "You completed this on " + (new Date()).toDateString();
    }

    if(!obj.actions[id][actionId]) {
      obj.actions[id][actionId] = {"agree" : agree ? agree : false, "done" : done ? done : false, "history" : [log]};
    } else {
      if(agree===true || agree===false) obj.actions[id][actionId].agree=agree;
      if(done===true || done===false) obj.actions[id][actionId].done=done;
      if(log){
        if(obj.actions[id][actionId].history) obj.actions[id][actionId].history.unshift(log);
        else obj.actions[id][actionId].done.history = [log];
      }
    }

    if(reason && obj.actions[id][actionId].agree === false){
      obj.actions[id][actionId].reason = reason;
    } else {
      delete obj.actions[id][actionId].reason;
    }

    setObj(obj);
    showSaved();
  };

  var ignoreAction = function(id, actionId){
    var obj = getObj();
    obj.actions[id][actionId].agree=null;
    delete obj.actions[id][actionId].reason;
    //obj.actions[id][actionId].done=null;
    setObj(obj);
  };

  var listActions = function(id, pathwayId){
    var obj = getObj(), arr = [];
    if(!id) return obj.actions;
    if(!obj.actions[id]) return arr;
    for(var prop in obj.actions[id]){
      obj.actions[id][prop].id = prop;
      if(!obj.actions[id][prop].text)
        arr.push(obj.actions[id][prop]);
    }
    return arr;
  };

  var editPatientAgree = function(pathwayId, pathwayStage, patientId, item, agree){
    var obj = getObj();
    if(!pathwayId || !pathwayStage) alert("EDITPATIENTAGREE");

    if(!obj.agrees[patientId]) obj.agrees[patientId] = [];
    var items = obj.agrees[patientId].filter(function(val){
      return val.pathwayId === pathwayId && val.pathwayStage === pathwayStage && val.item === item;
    });

    var log = "You " + (agree ? "" : "dis") + "agreed with this on " + (new Date()).toDateString();

    if(items.length===1) {
      items[0].agree = agree;
      items[0].history.push(log);
    } else if(items.length==0){
      obj.agrees[patientId].push({"pathwayId":pathwayId, "pathwayStage":pathwayStage, "item":item, "agree":agree, "history" : [log]});
    } else {
      console.log("ERRORRR!!!!!!!");
    }

    setObj(obj);
  };

  var getPatientAgree = function(pathwayId, pathwayStage, patientId, item){
    var obj = getObj();

    if(!obj.agrees[patientId]) return null;
    var item = obj.agrees[patientId].filter(function(val){
      return val.pathwayId === pathwayId && val.pathwayStage === pathwayStage && val.item === item;
    });

    if(item.length===1) {
        return item[0].agree;
    }
    return null;
  };

	/**************
	 *** Layout ***
	 **************/

  var switchTo121Layout = function(){
    if(local.layout === "121") return;
    local.layout === "121";
    farLeftPanel.removeClass('col-lg-6').addClass('col-lg-3').show();
    topPanel.hide();
    topLeftPanel.removeClass('col-xl-6').html("").hide();
    bottomLeftPanel.removeClass('col-xl-6').html("").hide();
    topRightPanel.addClass('col-xl-12').removeClass('col-xl-6').show();
    bottomRightPanel.addClass('col-xl-12').removeClass('col-xl-6').show();
    midPanel.removeClass('col-xl-8').addClass('col-xl-4').show();
    farRightPanel.removeClass('col-xl-8').addClass('col-xl-4').show();
  };

  var switchTo110Layout = function(){
    if(local.layout === "110") return;
    local.layout === "110";
    farLeftPanel.removeClass('col-lg-3').addClass('col-lg-6').show();
    topPanel.hide();
    topLeftPanel.hide();
    bottomLeftPanel.hide();
    topRightPanel.hide();
    bottomRightPanel.hide();
    midPanel.hide();
    farRightPanel.removeClass('col-xl-4').addClass('col-xl-8').show();
  };

  var switchTo120Layout = function(){
    if(local.layout === "120") return;
    local.layout === "120";
    farLeftPanel.removeClass('col-lg-6').addClass('col-lg-3').show();
    topPanel.hide();
    topLeftPanel.removeClass('col-xl-6').html("").hide();
    bottomLeftPanel.removeClass('col-xl-6').html("").hide();
    topRightPanel.addClass('col-xl-12').removeClass('collg-6').show();
    bottomRightPanel.addClass('col-xl-12').removeClass('col-xl-6').show();
    midPanel.removeClass('col-xl-8').addClass('col-xl-4').show();
    farRightPanel.hide();
  };

	var switchTo221Layout = function(){
    if(local.layout === "221") return;
    local.layout === "221";
    farLeftPanel.hide();
    topPanel.hide();
    topLeftPanel.addClass('col-xl-6').show();
    bottomLeftPanel.addClass('col-xl-6').show();
    topRightPanel.removeClass('col-xl-12').addClass('col-xl-6').show();
    bottomRightPanel.removeClass('col-xl-12').addClass('col-xl-6').show();
    midPanel.removeClass('col-xl-4').addClass('col-xl-8').show();
    farRightPanel.removeClass('col-xl-8').addClass('col-xl-4').show();
	};

  var updateTitle = function(title, tooltip){
    $('.pagetitle').html(title).attr('title', tooltip).tooltip({delay: { "show": 1000, "hide": 100 }});
  }

	var showSidePanel = function() {
    if(local.elements.navigtion) return;
    local.elements.navigtion=true;
		$('#main').addClass('content');
		$('#topnavbar').addClass('full');
		$('#aside-toggle').show();
		$('#bottomnavbar').hide();
	};

	var hideSidePanel = function() {
    if(local.elements.navigtion===false) return;
    local.elements.navigtion=false;
		$('#main').removeClass('content');
		$('#topnavbar').removeClass('full');
		$('#aside-toggle').hide();
		$('#bottomnavbar').show();
	};

  var showHeaderBarItems = function() {
    if(local.elements.headerbar) return;
    local.elements.headerbar = true;
    $('.hide-if-logged-out').show();
  };

  var hideHeaderBarItems = function() {
    if(local.elements.headerbar===false) return;
    local.elements.headerbar = false;
    $('.hide-if-logged-out').hide();
  };

	/**************
	 *** Panels ***
	 **************/

  var hideAllPanels = function(){
    topLeftPanel.hide();
    bottomLeftPanel.hide();
    topRightPanel.hide();
    bottomRightPanel.hide();
    farLeftPanel.hide();
    farRightPanel.hide();
    topPanel.hide();
  };

	var createPanel = function(templateSelector, data, templates){
		var template = templateSelector.html();
		Mustache.parse(template);   // optional, speeds up future uses
		if(templates) {
			for(var o in templates) {
				if(templates.hasOwnProperty(o))	{
					Mustache.parse(templates[o]);
				}
			}
		}
		var rendered = Mustache.render(template, data, templates);
    return rendered;
	};

	var createPanelShow = function(templateSelector, panelSelector, data, templates){
		var rendered = createPanel(templateSelector, data, templates);
		panelSelector.html(rendered).show();
	};

	var showPanel = function(pathwayStage, location, enableHover) {
		if(pathwayStage === local.categories.monitoring.name) showMonitoringPanel(location, enableHover);
		if(pathwayStage === local.categories.treatment.name) showTreatmentPanel(location, enableHover);
		if(pathwayStage === local.categories.diagnosis.name) showDiagnosisPanel(location, enableHover);
		if(pathwayStage === local.categories.exclusions.name) showExclusionsPanel(location, enableHover);

		if(enableHover) highlightOnHoverAndEnableSelectByClick(location);
    else location.children('div').addClass('unclickable');
	};

	var showMonitoringPanel = function(location, enableHover) {
		var percentChange = local.data[local.pathwayId].monitoring.trend[1][1]-local.data[local.pathwayId].monitoring.trend[1][30];
		var numberChange = local.data[local.pathwayId].monitoring.trend[2][1]-local.data[local.pathwayId].monitoring.trend[2][30];
		createPanelShow(monitoringPanel, location, {
			percent: local.data[local.pathwayId].monitoring.trend[1][1],
			percentChange: Math.abs(percentChange),
			percentUp: percentChange>=0,
			number: local.data[local.pathwayId].monitoring.trend[2][1],
			numberUp: numberChange>=0,
			numberChange: Math.abs(numberChange),
      pathway: local.pathwayNames[local.pathwayId],
      title: local.data[local.pathwayId].monitoring.panelTitle
			}, {"change-bar": $('#change-bar').html()}
		);

		destroyCharts(['monitoring-chart']);
    setTimeout(function(){
  		local.charts["monitoring-chart"] = c3.generate({
  			bindto: '#monitoring-chart',
  			data: {
  				x: 'x',
  				columns: local.data[local.pathwayId].monitoring.trend,
  				axes: {
  					"%" : 'y',
  					"n" : 'y2'
  				}
  			},
        zoom: {
            enabled: true
        },
        tooltip: {
          format: {
            title: function (x) { return x.toDateString() + (enableHover ? '<br>Click for more detail' : ''); }/*,
            value: function (value) { return  enableHover ? undefined : value;}*/
          }
        },
  			axis: {
  				x: {
  					type: 'timeseries',
  					tick: {
  						format: '%d-%m-%Y',
  						count: 7,
  						culling: {
  							max: 4
  						}
  					},
            label: {
              text: 'Date',
              position: 'outer-center'
            }
  				},
  				y : {
  					min : 0,
            label: {
              text: 'Proportion (%)',
              position: 'outer-middle'
            }
  				},
  				y2: {
  					show: true,
  					min: 0,
            label: {
              text: 'Patient count (n)',
              position: 'outer-middle'
            }
  				}
  			},
  			point: {
  				show: false
  			},
  			size: {
  				height: null
  			}
  			/*grid: {
  			 x: {
  			 lines: [{value: data[0][60], text: 'Action plan downloaded'}, {value: data[0][330], text: 'Action plan downloaded'}]
  			 }
  			 }*/
  		});
    },1);
	};

	var showTreatmentPanel = function(location, enableHover) {
		var percentChange = local.data[local.pathwayId].treatment.trend[1][1]-local.data[local.pathwayId].treatment.trend[1][30];
		var numberChange = local.data[local.pathwayId].treatment.trend[2][1]-local.data[local.pathwayId].treatment.trend[2][30];
		createPanelShow(treatmentPanel, location, {
			percent: local.data[local.pathwayId].treatment.trend[1][1],
			percentChange: Math.abs(percentChange),
			percentUp: percentChange>=0,
			number: local.data[local.pathwayId].treatment.trend[2][1],
			numberUp: numberChange>=0,
			numberChange: Math.abs(numberChange),
      pathway: local.pathwayNames[local.pathwayId],
      title: local.data[local.pathwayId].treatment.panelTitle
			}, {"change-bar": $('#change-bar').html()}
		);

		destroyCharts(['treatment-chart']);
    setTimeout(function(){
  		local.charts["treatment-chart"] = c3.generate({
  			bindto: '#treatment-chart',
  			data: {
  				x: 'x',
  				columns: local.data[local.pathwayId].treatment.trend,
  				axes: {
  					"%" : 'y',
  					"n" : 'y2'
  				}
  			},
        zoom: {
            enabled: true
        },
        tooltip: {
          format: {
            title: function (x) { return x.toDateString() + (enableHover ? '<br>Click for more detail' : ''); }/*,
            value: function (value) { return  enableHover ? undefined : value;}*/
          }
        },
  			axis: {
  				x: {
  					type: 'timeseries',
  					tick: {
  						format: '%d-%m-%Y',
  						count: 7,
  						culling: {
  							max: 4
  						}
  					},
            label: {
              text: 'Date',
              position: 'outer-center'
            }
  				},
  				y : {
  					min : 0,
            label: {
              text: 'Proportion (%)',
              position: 'outer-middle'
            }
  				},
  				y2: {
  					show: true,
  					min: 0,
            label: {
              text: 'Patient count (n)',
              position: 'outer-middle'
            }
  				}
  			},
  			point: {
  				show: false
  			},
  			size: {
  				height: null
  			}/*,
  			 grid: {
  			 x: {
  			 lines: [{value: data[0][60], text: 'Action plan downloaded'}, {value: data[0][330], text: 'Action plan downloaded'}]
  			 }
  			 }*/
  		});
    },1);
	};

	var showDiagnosisPanel = function(location, enableHover) {
		createPanelShow(diagnosisPanel, location, {
      pathway: local.pathwayNames[local.pathwayId],
      title: local.data[local.pathwayId].diagnosis.panelTitle,
      number: local.data[local.pathwayId].diagnosis.n,
			numberUp: local.data[local.pathwayId].diagnosis.change>=0,
			numberChange: Math.abs(local.data[local.pathwayId].diagnosis.change)
    }, {"change-bar-number": $('#change-bar-number').html()});

    destroyCharts(['diagnosis-chart']);
    setTimeout(function(){
  		local.charts["diagnosis-chart"] = c3.generate({
  			bindto: '#diagnosis-chart',
  			data: {
  				x: 'x',
  				columns: local.data[local.pathwayId].diagnosis.trend,
  				axes: {
  					"%" : 'y',
  					"n" : 'y2'
  				}
  			},
        zoom: {
            enabled: true
        },
        tooltip: {
          format: {
            title: function (x) { return x.toDateString() + (enableHover ? '<br>Click for more detail' : ''); }/*,
            value: function (value) { return  enableHover ? undefined : value;}*/
          }
        },
  			axis: {
  				x: {
  					type: 'timeseries',
  					tick: {
  						format: '%d-%m-%Y',
  						count: 7,
  						culling: {
  							max: 4
  						}
  					},
            label: {
              text: 'Date',
              position: 'outer-center'
            }
  				},
  				y : {
  					min : 0,
            label: {
              text: 'Proportion (%)',
              position: 'outer-middle'
            }
  				},
  				y2: {
  					show: true,
  					min: 0,
            label: {
              text: 'Patient count (n)',
              position: 'outer-middle'
            }
  				}
  			},
  			point: {
  				show: false
  			},
  			size: {
  				height: null
  			}
  			/*grid: {
  			 x: {
  			 lines: [{value: data[0][60], text: 'Action plan downloaded'}, {value: data[0][330], text: 'Action plan downloaded'}]
  			 }
  			 }*/
  		});
    },1);
	};

	var showExclusionsPanel = function(location, enableHover) {
		createPanelShow(exclusionPanel, location, {
      pathway: local.pathwayNames[local.pathwayId],
      title: local.data[local.pathwayId].exclusions.panelTitle,
      number: local.data[local.pathwayId].exclusions.n,
			numberUp: local.data[local.pathwayId].exclusions.change>=0,
			numberChange: Math.abs(local.data[local.pathwayId].exclusions.change)
    }, {"change-bar-number": $('#change-bar-number').html()});

    destroyCharts(['exclusion-chart']);
    setTimeout(function(){
  		local.charts["exclusion-chart"] = c3.generate({
  			bindto: '#exclusion-chart',
  			data: {
  				x: 'x',
  				columns: local.data[local.pathwayId].exclusions.trend,
  				axes: {
  					"%" : 'y',
  					"n" : 'y2'
  				}
  			},
        zoom: {
            enabled: true
        },
        tooltip: {
          format: {
            title: function (x) { return x.toDateString() + (enableHover ? '<br>Click for more detail' : ''); }/*,
            value: function (value) { return  enableHover ? undefined : value;}*/
          }/*,
          position: function (data, width, height, element) {
            console.log(data,width, height, element);
            return {top: height};
          }*/
        },
  			axis: {
  				x: {
  					type: 'timeseries',
  					tick: {
  						format: '%d-%m-%Y',
  						count: 7,
  						culling: {
  							max: 4
  						}
  					},
            label: {
              text: 'Date',
              position: 'outer-center'
            }
  				},
  				y : {
  					min : 0,
            label: {
              text: 'Proportion (%)',
              position: 'outer-middle'
            }
  				},
  				y2: {
  					show: true,
  					min: 0,
            label: {
              text: 'Patient count (n)',
              position: 'outer-middle'
            }
  				}
  			},
  			point: {
  				show: false
  			},
  			size: {
  				height: null
  			}
  			/*grid: {
  			 x: {
  			 lines: [{value: data[0][60], text: 'Action plan downloaded'}, {value: data[0][330], text: 'Action plan downloaded'}]
  			 }
  			 }*/
  		});
    },1);
	};

  var showPatientDropdownPanel = function(location){
    createPanelShow($('#patient-dropdown-panel'),location, {"patients" : Object.keys(local.data.patients)});
  };

  var createPatientPanel = function(pathwayStage, standard){
    var tabData = [];
    for(var key in local.data[local.pathwayId][pathwayStage].standards){
      tabData.push({"text": local.data[local.pathwayId][pathwayStage].standards[key].tab, "active" : key===standard ,"url": window.location.hash.replace(/\/no.*/g,'\/no/'+key)});
    }
    return createPanel(patientsPanelTemplate,{"pathwayStage" : pathwayStage,"header": local.data[local.pathwayId][pathwayStage].standards[standard].title,"url":window.location.hash.replace(/\/yes.*/g,'').replace(/\/no.*/g,''), "tabs": tabData, "text" : local.data[local.pathwayId][pathwayStage].text},{"content" : $('#patients-panel-no').html(),"tab-header" : $('#patients-panel-no-tabs').html(),"tab-content" : $('#patients-panel-no-page').html()});
  };

  var createPatientPanelOk = function(pathwayStage){
    return createPanel(patientsPanelTemplate,{"ok": true, "pathwayStage" : pathwayStage,"url":window.location.hash.replace(/\/yes/g,'').replace(/\/no/g,''), "text" : local.data[local.pathwayId][pathwayStage].text},{"content" : $('#patients-panel-yes').html()});
  };

  var wireUpPatientPanel = function(pathwayStage, location, standard){
    patientsPanel = $('#patients');

		patientsPanel.on('click', 'thead tr th.sortable', function(){	//Sort columns when column header clicked
			var sortAsc = !$(this).hasClass('sort-asc');
			if(sortAsc) {
				$(this).removeClass('sort-desc').addClass('sort-asc');
			} else {
				$(this).removeClass('sort-asc').addClass('sort-desc');
			}
			populatePatientPanel(local.pathwayId, local.selected, standard, local.subselected, $(this).index(), sortAsc);
		}).on('click', 'tbody tr', function(e){	//Select individual patient when row clicked
			$('.list-item').removeClass('highlighted');
			$(this).addClass('highlighted');

      var patientId = $(this).find('td button').attr('data-patient-id');

      showPathwayStagePatientView(patientId, local.pathwayId, local.selected, local.data.patients[patientId].breach.length>1);

			e.preventDefault();
      e.stopPropagation();
		}).on('click', 'tbody tr button', function(e){
			//don't want row selected if just button pressed?
			e.preventDefault();
			e.stopPropagation();
		});

    local.selected = pathwayStage;
    local.subselected = null;

		location.off('click','.panel-body');
		location.on('click', '.panel-body', function(){
			if(!local.chartClicked){
        /*jshint unused: true*/
				$('path.c3-bar').attr('class', function(index, classNames) {
					return classNames.replace(/_unselected_/g, '');
				});
        /*jshint unused: false*/

				if(local.charts['breakdown-chart']) local.charts['breakdown-chart'].unselect();

        populatePatientPanel(local.pathwayId, pathwayStage, standard, null);
        local.subselected = null;

        farRightPanel.fadeOut(200);
				//hideAllPanels();
			}
			local.chartClicked=false;
		});

		destroyCharts(['breakdown-chart']);
    setTimeout(function(){
  		local.charts['breakdown-chart'] = c3.generate({
  			bindto: '#breakdown-chart',
  			tooltip: {
  				format: {
            name: function (name,a,b) {
              return "n";
            },
  					value: function (value) { //function(value, ratio, id, index) {
  						return value;
  					}
  				}
  			},
  			data: {
  				columns: [
            ["Patients"].concat(local.data[local.pathwayId][pathwayStage].standards[standard].opportunities.map(function(val){return val.n;}))
          ],
  				type: 'bar',
          labels: true,
          color: function (color, d) {
            return local.colors[d.index];
          },
          selection:{
            enabled: true
          },
  				onclick: function (d) {
  					selectPieSlice('breakdown-chart', d);
  					populatePatientPanel(local.pathwayId, pathwayStage, standard, local.data[local.pathwayId][pathwayStage].standards[standard].opportunities[d.index].name);
  					local.subselected = d.id

            //colour table appropriately - need to add opacity
            var sliceColourHex = local.colors[d.index];
            var shorthandRegex = /^#?([a-f\d])([a-f\d])([a-f\d])$/i;
            sliceColourHex = sliceColourHex.replace(shorthandRegex, function(m, r, g, b) {
                return r + r + g + g + b + b;
            });
            var result = /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i.exec(sliceColourHex);
            var opacity = 0.2;
            var sliceColour = 'rgba(' + parseInt(result[1], 16) + ',' + parseInt(result[2], 16) + ',' + parseInt(result[3], 16) + ',' + opacity + ')';

            $('.table.patient-list.table-head-hidden').css({"backgroundColor": sliceColour});
  				}
  			},
        bar: {
          width: {
            ratio: 0.5
          }
        },
  			legend: {
  				show: false
  			},
        axis: {
  				x: {
  					type: 'category',
  					categories: local.data[local.pathwayId][pathwayStage].standards[standard].opportunities.map(function(val){return val.name;}),
            label: {
              text: 'Disease',
              position: 'outer-center'
            }
  				},
          y : {
            label: {
              text: 'Patient count (n)',
              position: 'outer-middle'
            }
          }
  			}
  		});
    },1);
  };

  var wireUpPatientPanelOk = function(pathwayStage, location){
    patientsPanel = $('#patients');

		patientsPanel.on('click', 'thead tr th.sortable', function(){	//Sort columns when column header clicked
			var sortAsc = !$(this).hasClass('sort-asc');
			if(sortAsc) {
				$(this).removeClass('sort-desc').addClass('sort-asc');
			} else {
				$(this).removeClass('sort-asc').addClass('sort-desc');
			}
			populatePatientPanelOk(local.pathwayId, local.selected, local.subselected, $(this).index(), sortAsc);
		}).on('click', 'tbody tr', function(e){	//Select individual patient when row clicked
			/*$('.list-item').removeClass('highlighted');
			$(this).addClass('highlighted');

      var patientId = $(this).find('td button').attr('data-patient-id');

      showPathwayStagePatientView(patientId, local.pathwayId, local.selected, local.data.patients[patientId].breach.length>1);
*/
			e.preventDefault();
      e.stopPropagation();
		}).on('click', 'tbody tr button', function(e){
			//don't want row selected if just button pressed?
			e.preventDefault();
			e.stopPropagation();
		});

    local.selected = pathwayStage;
    local.subselected = null;
  };

  var showAllPatientPanel = function(location) {
		createPanelShow($('#all-patients-panel'),location);

		patientsPanel = $('#patients');

		patientsPanel.on('click', 'tbody tr', function(e){	//Select individual patient when row clicked
			$('.list-item').removeClass('highlighted');
			$(this).addClass('highlighted');

      var patientId = $(this).find('td button').attr('data-patient-id');

      showAllPatientView(patientId);

			e.preventDefault();
			e.stopPropagation();
		}).on('click', 'tbody tr button', function(e){
			//don't want row selected if just button pressed?
			e.preventDefault();
			e.stopPropagation();
		});

    /*var c = patientsPanel.getNiceScroll();
    if(c && c.length>0){
      c.resize();
    } else {
      patientsPanel.niceScroll({
  			cursoropacitymin: 0.3,
  			cursorwidth: "7px",
  			horizrailenabled: false
  		});
    }*/
	};

  var showTeamActionPlanPanel = function(location){
    createPanelShow($('#team-action-plan-panel'),location);

		suggestedPlanTeam = $('#suggestedPlanTeam');

		suggestedPlanTeam.on('click', '.cr-styled input[type=checkbox]', function(){
      var ACTIONID = $(this).closest('tr').data('id');
      editAction("team", ACTIONID, null, this.checked);

      if(this.checked) {
        recordEvent(local.pathwayId, "team", "Item completed");
        var self = this;
        $(self).parent().attr("title","").attr("data-original-title","").tooltip('fixTitle').tooltip('hide');
        wireUpTooltips();
        setTimeout(function(e){
          $(self).parent().fadeOut(300, function(){
            var parent = $(this).parent();
            $(this).replaceWith(createPanel($('#checkbox-template'),{"done":true}));
            parent.find('button').on('click', function(){
              ACTIONID = $(this).closest('tr').data('id');
              editAction("team", ACTIONID, null, false);
              $(this).replaceWith(createPanel($('#checkbox-template'),{"done":false}));
              updateTeamSapRows();
            });
          });
        },1000);
      }

			updateTeamSapRows();
		});

    $('#personalPlanTeam').on('click', 'input[type=checkbox]', function(){
			var PLANID = $(this).closest('tr').data("id");
      editPlan(PLANID, null, this.checked);

      if(this.checked){
        $(this).parent().parent().parent().addClass('success');
        recordEvent(local.pathwayId, "team", "Personal plan item");
        var self = this;
        $(self).parent().attr("title","").attr("data-original-title","").tooltip('fixTitle').tooltip('hide');
        setTimeout(function(e){
          $(self).parent().fadeOut(300, function(){
            var parent = $(this).parent();
            $(this).replaceWith(createPanel($('#checkbox-template'),{"done":true}));
            wireUpTooltips();
            parent.find('button').on('click', function(){
              PLANID = $(this).closest('tr').data('id');
              editPlan("team", PLANID, null, false);
              $(this).replaceWith(createPanel($('#checkbox-template'),{"done":false}));
              updateTeamSapRows();
            });
          });
        },1000);
      }

		}).on('click', '.btn-undo', function(e){
      var PLANID = $(this).closest('tr').data('id');
      editPlan(PLANID, null, false);
      $(this).replaceWith(createPanel($('#checkbox-template'),{"done":false}));
      updateTeamSapRows();
      e.stopPropagation();
    });

    var teamTab = $('#tab-plan-team'),  current;
		teamTab.on('click', '.edit-plan', function(){
      var PLANID = $(this).closest('tr').data("id");

      $('#editActionPlanItem').val($($(this).closest('tr').children('td')[0]).find('span').text());

      $('#editPlan').off('hidden.bs.modal').on('hidden.bs.modal', function () {
        displayPersonalisedTeamActionPlan($('#personalPlanTeam'));
      }).off('shown.bs.modal').on('shown.bs.modal', function () {
        $('#editActionPlanItem').focus();
      }).off('click','.save-plan').on('click', '.save-plan',function(){

        editPlan(PLANID, $('#editActionPlanItem').val());

        $('#editPlan').modal('hide');
      }).off('keyup','#editActionPlanItem').on('keyup', '#editActionPlanItem',function(e){
        if(e.which === 13) $('#editPlan .save-plan').click();
      }).modal();
		}).on('click', '.delete-plan', function(){
      var PLANID = $(this).closest('tr').data("id");

      $('#team-delete-item').html($($(this).closest('tr').children('td')[0]).find('span').text());

      $('#deletePlan').off('hidden.bs.modal').on('hidden.bs.modal', function () {
        displayPersonalisedTeamActionPlan($('#personalPlanTeam'));
      }).off('click','.delete-plan').on('click', '.delete-plan',function(){
        deletePlan(PLANID);

        $('#deletePlan').modal('hide');
      }).modal();
		}).on('click', '.add-plan', function(){
      recordPlan("team", $(this).parent().parent().find('textarea').val(), local.pathwayId);

			displayPersonalisedTeamActionPlan($('#personalPlanTeam'));
		}).on('change', '.btn-toggle input[type=checkbox]', function(){
      updateTeamSapRows();
    }).on('click', '.btn-undo', function(e){
      var ACTIONID = $(this).closest('tr').data('id');
      editAction("team", ACTIONID, null, false);
      $(this).replaceWith(createPanel($('#checkbox-template'),{"done":false}));
      updateTeamSapRows();
    }).on('click', '.btn-yes,.btn-no', function(e){
      var checkbox = $(this).find("input[type=checkbox]");
      var other = $(this).parent().find($(this).hasClass("btn-yes") ? ".btn-no" : ".btn-yes");
      var ACTIONID = $(this).closest('tr').data('id');
      if($(this).hasClass("active") && other.hasClass("inactive") && !$(this).closest('tr').hasClass('success')){
        //unselecting
        if(checkbox.val()==="no"){
          launchTeamModal(local.selected, checkbox.closest('tr').children().first().children().first().text(), getReason("team", ACTIONID), function(){
            editAction("team", ACTIONID, false, null, local.reason);
            updateTeamSapRows();
            wireUpTooltips();
          }, function(){
            ignoreAction("team", ACTIONID);
            other.removeClass("inactive");
            checkbox.removeAttr("checked");
            checkbox.parent().removeClass("active");
            updateTeamSapRows();
            wireUpTooltips();
          });
          e.stopPropagation();
          e.preventDefault();
        } else {
          ignoreAction("team", ACTIONID);
          other.removeClass("inactive");
        }
      } else if((!$(this).hasClass("active") && other.hasClass("active")) || $(this).closest('tr').hasClass('success')) {
        //prevent clicking on unselected option or if the row is complete
        e.stopPropagation();
        e.preventDefault();
        return;
      } else {
        //selecting
        var self = this;
        if(checkbox.val()==="no") {
          launchTeamModal(local.selected, checkbox.closest('tr').children().first().children().first().text(), getReason("team", ACTIONID), function(){
            editAction("team", ACTIONID, false, null, local.reason);
            $(self).removeClass("inactive");

            checkbox.attr("checked","checked");
            checkbox.parent().addClass("active");
            //unselect other
            other.removeClass("active").addClass("inactive");
            other.find("input[type=checkbox]").prop("checked", false);
            updateTeamSapRows();
            wireUpTooltips();
          }), function(){

          };
          e.stopPropagation();
          e.preventDefault();
        }
        else {
          editAction("team", ACTIONID, true);
          $(this).removeClass("inactive");

          //unselect other
          other.removeClass("active").addClass("inactive");
          other.find("input[type=checkbox]").prop("checked", false);
        }
      }
		}).on('keyup', 'input[type=text]', function(e){
      if(e.which === 13) {
        teamTab.find('.add-plan').click();
      }
    });

    populateTeamSuggestedActionsPanel();
  };

  var createIndividualActionPlanPanel = function(pathwayStage) {
    return createPanel($('#individual-action-plan-panel'),{"pathwayStage" : pathwayStage || "default", "noHeader" : true});
  };

  var createIndividualActionPlanPanelShow = function(location, pathwayStage) {
    createPanelShow($('#individual-action-plan-panel'),location,{"pathwayStage" : pathwayStage || "default", "noHeader" : true});
  };

  var wireUpIndividualActionPlanPanel = function(pathwayId, pathwayStage, patientId, isMultiple) {
    individualTab = $('#tab-plan-individual');

    $('#advice-list').on('click', '.cr-styled input[type=checkbox]', function(){
      var ACTIONID = $(this).closest('tr').data('id');
      editAction(local.patientId, ACTIONID, null, this.checked);

      if(this.checked) {
        recordEvent(pathwayId, local.patientId, "Item completed");
        var self = this;
        $(self).parent().attr("title","").attr("data-original-title","").tooltip('fixTitle').tooltip('hide');
        setTimeout(function(e){
          $(self).parent().fadeOut(300, function(){
            var parent = $(this).parent();
            $(this).replaceWith(createPanel($('#checkbox-template'),{"done":true}));
            wireUpTooltips();
            parent.find('button').on('click', function(){
              ACTIONID = $(this).closest('tr').data('id');
              editAction(local.patientId, ACTIONID, null, false);
              $(this).replaceWith(createPanel($('#checkbox-template'),{"done":false}));
              updateIndividualSapRows();
            });
          });
        },1000);
      }

      updateIndividualSapRows();
    });

    $('#personalPlanIndividual').on('click', 'input[type=checkbox]', function(){
      var PLANID = $(this).closest('tr').data("id");
      editPlan(PLANID, null, this.checked);

      if(this.checked){
        $(this).parent().parent().parent().addClass('success');
        recordEvent(local.pathwayId, local.patientId, "Personal plan item");
        var self = this;
        $(self).parent().attr("title","").attr("data-original-title","").tooltip('fixTitle').tooltip('hide');
        setTimeout(function(e){
          $(self).parent().fadeOut(300, function(){
            var parent = $(this).parent();
            $(this).replaceWith(createPanel($('#checkbox-template'),{"done":true}));
            wireUpTooltips();
            parent.find('button').on('click', function(){
              PLANID = $(this).closest('tr').data('id');
              editPlan(local.patientId, PLANID, null, false);
              $(this).replaceWith(createPanel($('#checkbox-template'),{"done":false}));
              updateIndividualSapRows();
            });
          });
        },1000);
      }
    }).on('click', '.btn-undo', function(e){
      var PLANID = $(this).closest('tr').data('id');
      editPlan(PLANID, null, false);
      $(this).replaceWith(createPanel($('#checkbox-template'),{"done":false}));
      updateIndividualSapRows();
      e.stopPropagation();
    });

    individualTab.on('click', '.edit-plan', function(){
      var PLANID = $(this).closest('tr').data("id");

      $('#editActionPlanItem').val($($(this).closest('tr').children('td')[0]).find('span').text());

      $('#editPlan').off('hidden.bs.modal').on('hidden.bs.modal', function () {
        displayPersonalisedIndividualActionPlan(local.patientId, $('#personalPlanIndividual'));
      }).off('shown.bs.modal').on('shown.bs.modal', function () {
        $('#editActionPlanItem').focus();
      }).off('click','.save-plan').on('click', '.save-plan',function(){

        editPlan(PLANID, $('#editActionPlanItem').val());

        $('#editPlan').modal('hide');
      }).off('keyup','#editActionPlanItem').on('keyup', '#editActionPlanItem',function(e){
        if(e.which === 13) $('#editPlan .save-plan').click();
      }).modal();
    }).on('click', '.delete-plan', function(){
      var PLANID = $(this).closest('tr').data("id");

      $('#individual-delete-item').html($($(this).closest('tr').children('td')[0]).find('span').text());

      $('#deletePlan').off('hidden.bs.modal').on('hidden.bs.modal', function () {
        displayPersonalisedIndividualActionPlan(local.patientId, $('#personalPlanIndividual'));
      }).off('click','.delete-plan').on('click', '.delete-plan',function(){
        deletePlan(PLANID);

        $('#deletePlan').modal('hide');
      }).modal();
    }).on('click', '.add-plan', function(){
      recordPlan(local.patientId, $(this).parent().parent().find('textarea').val(), pathwayId);

      displayPersonalisedIndividualActionPlan(local.patientId, $('#personalPlanIndividual'));
    }).on('change', '.btn-toggle input[type=checkbox]', function(){
      updateIndividualSapRows();
    }).on('click', '.btn-undo', function(e){
      var ACTIONID = $(this).closest('tr').data('id');
      editAction(local.patientId, ACTIONID, null, false);
      $(this).replaceWith(createPanel($('#checkbox-template'),{"done":false}));
      updateIndividualSapRows();
    }).on('click', '.btn-yes,.btn-no', function(e){
      var checkbox = $(this).find("input[type=checkbox]");
      var other = $(this).parent().find($(this).hasClass("btn-yes") ? ".btn-no" : ".btn-yes");
      var ACTIONID = $(this).closest('tr').data('id');
      if($(this).hasClass("active") && other.hasClass("inactive") && !$(this).closest('tr').hasClass('success')){
        //unselecting
        if(checkbox.val()==="no"){
          launchPatientActionModal(local.selected, checkbox.closest('tr').children().first().children().first().text(), getReason(local.patientId, ACTIONID), function(){
            editAction(local.patientId, ACTIONID, false, null, local.reason);
            updateIndividualSapRows();
            wireUpTooltips();
          }, function(){
            ignoreAction(local.patientId, ACTIONID);
            other.removeClass("inactive");
            checkbox.removeAttr("checked");
            checkbox.parent().removeClass("active");
            updateIndividualSapRows();
            wireUpTooltips();
          });
          e.stopPropagation();
          e.preventDefault();
        } else {
          ignoreAction(local.patientId, ACTIONID);
          other.removeClass("inactive");
        }
      } else if((!$(this).hasClass("active") && other.hasClass("active")) || $(this).closest('tr').hasClass('success')) {
        //prevent clicking on unselected option or if the row is complete
        e.stopPropagation();
        e.preventDefault();
        return;
      } else {
        //selecting
        var self = this;
        if(checkbox.val()==="no") {
          launchPatientActionModal(local.selected, checkbox.closest('tr').children().first().children().first().text(), getReason(local.patientId, ACTIONID), function(){
            editAction(local.patientId, ACTIONID, false, null, local.reason);
            $(self).removeClass("inactive");

            checkbox.attr("checked","checked");
            checkbox.parent().addClass("active");
            //unselect other
            other.removeClass("active").addClass("inactive");
            other.find("input[type=checkbox]").prop("checked", false);
            updateIndividualSapRows();
            wireUpTooltips();
          }), function(){

          };
          e.stopPropagation();
          e.preventDefault();
        }
        else {
          editAction(local.patientId, ACTIONID, true);
          $(this).removeClass("inactive");

          //unselect other
          other.removeClass("active").addClass("inactive");
          other.find("input[type=checkbox]").prop("checked", false);
        }
      }
    }).on('keyup', 'input[type=text]', function(e){
      if(e.which === 13) {
        individualTab.find('.add-plan').click();
      }
    });

    populateIndividualSuggestedActions(patientId, pathwayId, pathwayStage, isMultiple);
  };

	var showIndividualActionPlanPanel = function(location, pathwayId, pathwayStage, patientId, isMultiple) {
    createIndividualActionPlanPanelShow(location, pathwayStage);
    wireUpIndividualActionPlanPanel(pathwayId, pathwayStage, patientId, isMultiple);
	};

  var createQualStanPanel = function(pathwayId, pathwayStage, patientId, isMultiple){
    var data = {"nhsNumber" : local.patLookup ? local.patLookup[patientId] : patientId, "patientId" : patientId, "isMultiple" : isMultiple};

    var subsection = local.data.patients[patientId].breach.filter(function(v) {return v.pathwayId === pathwayId && v.pathwayStage === pathwayStage;})[0].subsection;

    data.section = {
      "name" : local.data[pathwayId][pathwayStage].bdown[subsection].name,
      "agree" : getPatientAgree(pathwayId, pathwayStage, patientId, "section") === true,
      "disagree" : getPatientAgree(pathwayId, pathwayStage, patientId, "section") === false,
    }
    data.category = {
      "name" : local.data.patients[patientId].category,
      "agree" : getPatientAgree(pathwayId, pathwayStage, patientId, "category") === true,
      "disagree" : getPatientAgree(pathwayId, pathwayStage, patientId, "category") === false,
    }

    return createPanel($('#qual-standard'), data, {"chk" : $('#checkbox-template').html() });
  };

  var wireUpQualStan = function(pathwayId, pathwayStage){
    $('#individual-panel-classification').on('change', '.btn-toggle input[type=checkbox]', function(){
      updateQualStan();
    }).on('click', '.btn-yes,.btn-no', function(e){
      var checkbox = $(this).find("input[type=checkbox]");
      var other = $(this).parent().find($(this).hasClass("btn-yes") ? ".btn-no" : ".btn-yes");
      var isClassification = $(this).closest('div').data("isClassification")!==undefined;

      if($(this).hasClass("active") && other.hasClass("inactive")){
        //unselecting
        editPatientAgree(pathwayId, pathwayStage, local.patientId, isClassification ? "section" : "category", null);
        other.removeClass("inactive");
      } else if(!$(this).hasClass("active") && other.hasClass("active")) {
        //prevent clicking on unselected option
        e.stopPropagation();
        e.preventDefault();
        return;
      } else {
        $(this).removeClass("inactive");
        //unselect other
        other.removeClass("active").addClass("inactive");
        other.find("input[type=checkbox]").prop("checked", false);

        //selecting
        if(checkbox.val()==="no") launchPatientModal(pathwayId, pathwayStage, local.patientId, $(this).closest('div').data('text'), !isClassification);

        editPatientAgree(pathwayId, pathwayStage, local.patientId, isClassification ? "section" : "category", checkbox.val()==="yes");

      }
		});

    updateQualStan();
  };

  var updateQualStan = function(){
    //$('#individual-panel-classification table').removeClass('panel-green').removeClass('panel-red');
    $('#individual-panel-classification').find('div').each(function(){
      var self = $(this);
      var any = false;
      self.find('.btn-toggle input[type=checkbox]:checked').each(function(){
        var isClassification = $(this).closest("div").data("isClassification")!==undefined;
        any = true;
        var item = getObj().agrees[local.patientId].filter(function(i){return isClassification ? i.item==="section" : i.item!=="section" });
        if(this.value==="yes"){
          //$(this).closest('table').addClass('panel-green');
          if(item && item[0].history){
            var tool = item[0].history[0] + " - click again to cancel";
            $(this).parent().attr("title", tool).attr("data-original-title", tool).tooltip('fixTitle').tooltip('hide');
          } else {
            $(this).parent().attr("title", "You agreed - click again to cancel").tooltip('fixTitle').tooltip('hide');
          }
        } else {
          //$(this).closest('table').addClass('panel-red');
          if(item && item[0].history){
            var tool = item[0].history[0] + " - click again to edit/cancel";
            $(this).parent().attr("title", tool).attr("data-original-title", tool).tooltip('fixTitle').tooltip('hide');
          } else {
            $(this).parent().attr("title", "You disagreed - click again to edit/cancel").tooltip('fixTitle').tooltip('hide');
          }
        }
      });

      if(self.find('.btn-toggle input[type=checkbox]:not(:checked)').length==1){
        self.find('.btn-toggle input[type=checkbox]:not(:checked)').parent().addClass("inactive").attr("title", "").attr("data-original-title", "").tooltip('fixTitle').tooltip('hide');
      }

      if(!any){
        self.find('.btn-toggle.btn-yes').attr("title", "Click to agree with this action").tooltip('fixTitle').tooltip('hide');
        self.find('.btn-toggle.btn-no').attr("title", "Click to disagree with this action").tooltip('fixTitle').tooltip('hide');
      }

      wireUpTooltips();
    });

    wireUpTooltips();
  };

  var wireUpWelcomePage = function(pathwayId, pathwayStage){
    $('#team-task-panel').on('click', '.cr-styled input[type=checkbox]', function(){
      var ACTIONID = $(this).closest('tr').data('id');
      editAction("team", ACTIONID, null, this.checked);

      if(this.checked) {
        recordEvent(local.pathwayId, "team", "Item completed");
        var self = this;
        $(self).parent().attr("title","").attr("data-original-title","").tooltip('fixTitle').tooltip('hide');
        wireUpTooltips();
        setTimeout(function(e){
          $(self).parent().fadeOut(300, function(){
            var parent = $(this).parent();
            $(this).replaceWith(createPanel($('#checkbox-template'),{"done":true}));
            parent.find('button').on('click', function(){
              ACTIONID = $(this).closest('tr').data('id');
              editAction("team", ACTIONID, null, false);
              $(this).replaceWith(createPanel($('#checkbox-template'),{"done":false}));
              updateWelcomePage();
            });
          });
        },1000);
      }
			updateWelcomePage();
		}).on('change', '.btn-toggle input[type=checkbox]', function(){
      updateWelcomePage();
    }).on('click', '.edit-plan', function(){
      var PLANID = $(this).closest('tr').data("id");

      $('#editActionPlanItem').val($($(this).closest('tr').children('td')[1]).find('span').text());

      $('#editPlan').off('hidden.bs.modal').on('hidden.bs.modal', function () {
        populateWelcomeTasks(!$('#outstandingTasks').parent().hasClass("active"));
      }).off('shown.bs.modal').on('shown.bs.modal', function () {
        $('#editActionPlanItem').focus();
      }).off('click','.save-plan').on('click', '.save-plan',function(){

        editPlan(PLANID, $('#editActionPlanItem').val());

        $('#editPlan').modal('hide');
      }).off('keyup','#editActionPlanItem').on('keyup', '#editActionPlanItem',function(e){
        if(e.which === 13) $('#editPlan .save-plan').click();
      }).modal();
		}).on('click', '.delete-plan', function(){
      var PLANID = $(this).closest('tr').data("id");

      $('#team-delete-item').html($($(this).closest('tr').children('td')[1]).find('span').text());

      $('#deletePlan').off('hidden.bs.modal').on('hidden.bs.modal', function () {
        populateWelcomeTasks(!$('#outstandingTasks').parent().hasClass("active"));
      }).off('click','.delete-plan').on('click', '.delete-plan',function(){
        deletePlan(PLANID);

        $('#deletePlan').modal('hide');
      }).modal();
		}).on('click', '.btn-undo', function(e){
      var ACTIONID = $(this).closest('tr').data('id');
      editAction("team", ACTIONID, null, false);
      $(this).replaceWith(createPanel($('#checkbox-template'),{"done":false}));
      updateWelcomePage();
    }).on('click', '.btn-yes,.btn-no', function(e){
      var checkbox = $(this).find("input[type=checkbox]");
      var other = $(this).parent().find($(this).hasClass("btn-yes") ? ".btn-no" : ".btn-yes");
      var ACTIONID = $(this).closest('tr').data('id');
      if($(this).hasClass("active") && other.hasClass("inactive") && !$(this).closest('tr').hasClass('success')){
        //unselecting
        if(checkbox.val()==="no"){
          launchTeamModal(local.selected, checkbox.closest('tr').children(':nth(1)').find('span').text(), getReason("team", ACTIONID), function(){
            editAction("team", ACTIONID, false, null, local.reason);
            updateWelcomePage();
            wireUpTooltips();
          }, function(){
            ignoreAction("team", ACTIONID);
            other.removeClass("inactive");
            checkbox.removeAttr("checked");
            checkbox.parent().removeClass("active");
            updateWelcomePage();
            wireUpTooltips();
          });
          e.stopPropagation();
          e.preventDefault();
        } else {
          ignoreAction("team", ACTIONID);
          other.removeClass("inactive");
        }
      } else if((!$(this).hasClass("active") && other.hasClass("active")) || $(this).closest('tr').hasClass('success')) {
        //prevent clicking on unselected option or if the row is complete
        e.stopPropagation();
        e.preventDefault();
        return;
      } else {
        //selecting
        var self = this;
        if(checkbox.val()==="no") {
          launchTeamModal(local.selected, checkbox.closest('tr').children(':nth(1)').find('span').text(), getReason("team", ACTIONID), function(){
            editAction("team", ACTIONID, false, null, local.reason);
            $(self).removeClass("inactive");

            checkbox.attr("checked","checked");
            checkbox.parent().addClass("active");
            //unselect other
            other.removeClass("active").addClass("inactive");
            other.find("input[type=checkbox]").prop("checked", false);
            updateWelcomePage();
            wireUpTooltips();
          }), function(){

          };
          e.stopPropagation();
          e.preventDefault();
        }
        else {
          editAction("team", ACTIONID, true);
          $(this).removeClass("inactive");

          //unselect other
          other.removeClass("active").addClass("inactive");
          other.find("input[type=checkbox]").prop("checked", false);
        }
      }
		});

    $('#individual-task-panel').on('click', '.cr-styled input[type=checkbox]', function(){
      var ACTIONID = $(this).closest('tr').data('id');
      var patientId = $(this).closest('tr').data('team-or-patient-id');
      editAction(patientId, ACTIONID, null, this.checked);

      if(this.checked) {
        recordEvent(local.pathwayId, patientId, "Item completed");
        var self = this;
        $(self).parent().attr("title","").attr("data-original-title","").tooltip('fixTitle').tooltip('hide');
        wireUpTooltips();
        setTimeout(function(e){
          $(self).parent().fadeOut(300, function(){
            var parent = $(this).parent();
            $(this).replaceWith(createPanel($('#checkbox-template'),{"done":true}));
            parent.find('button').on('click', function(){
              ACTIONID = $(this).closest('tr').data('id');
              editAction(patientId, ACTIONID, null, false);
              $(this).replaceWith(createPanel($('#checkbox-template'),{"done":false}));
              updateWelcomePage();
            });
          });
        },1000);
      }
			updateWelcomePage();
		}).on('change', '.btn-toggle input[type=checkbox]', function(){
      updateWelcomePage();
    }).on('click', '.edit-plan', function(){
      var PLANID = $(this).closest('tr').data("id");

      $('#editActionPlanItem').val($($(this).closest('tr').children('td')[2]).find('span').text());

      $('#editPlan').off('hidden.bs.modal').on('hidden.bs.modal', function () {
        populateWelcomeTasks(!$('#outstandingTasks').parent().hasClass("active"));
      }).off('shown.bs.modal').on('shown.bs.modal', function () {
        $('#editActionPlanItem').focus();
      }).off('click','.save-plan').on('click', '.save-plan',function(){

        editPlan(PLANID, $('#editActionPlanItem').val());

        $('#editPlan').modal('hide');
      }).off('keyup','#editActionPlanItem').on('keyup', '#editActionPlanItem',function(e){
        if(e.which === 13) $('#editPlan .save-plan').click();
      }).modal();
		}).on('click', '.delete-plan', function(){
      var PLANID = $(this).closest('tr').data("id");

      $('#team-delete-item').html($($(this).closest('tr').children('td')[2]).find('span').text());

      $('#deletePlan').off('hidden.bs.modal').on('hidden.bs.modal', function () {
        populateWelcomeTasks(!$('#outstandingTasks').parent().hasClass("active"));
      }).off('click','.delete-plan').on('click', '.delete-plan',function(){
        deletePlan(PLANID);

        $('#deletePlan').modal('hide');
      }).modal();
		}).on('click', '.btn-undo', function(e){
      var ACTIONID = $(this).closest('tr').data('id');
      var patientId = $(this).closest('tr').data('team-or-patient-id');
      editAction(patientId, ACTIONID, null, false);
      $(this).replaceWith(createPanel($('#checkbox-template'),{"done":false}));
      updateWelcomePage();
    }).on('click', '.btn-yes,.btn-no', function(e){
      var checkbox = $(this).find("input[type=checkbox]");
      var other = $(this).parent().find($(this).hasClass("btn-yes") ? ".btn-no" : ".btn-yes");
      var ACTIONID = $(this).closest('tr').data('id');
      var patientId = $(this).closest('tr').data('team-or-patient-id');
      if($(this).hasClass("active") && other.hasClass("inactive") && !$(this).closest('tr').hasClass('success')){
        //unselecting
        if(checkbox.val()==="no"){
          launchPatientActionModal(local.selected, checkbox.closest('tr').children(':nth(2)').find('span').text(), getReason(patientId, ACTIONID), function(){
            editAction(patientId, ACTIONID, false, null, local.reason);
            updateWelcomePage();
            wireUpTooltips();
          }, function(){
            ignoreAction(patientId, ACTIONID);
            other.removeClass("inactive");
            checkbox.removeAttr("checked");
            checkbox.parent().removeClass("active");
            updateWelcomePage();
            wireUpTooltips();
          });
          e.stopPropagation();
          e.preventDefault();
        } else {
          ignoreAction(patientId, ACTIONID);
          other.removeClass("inactive");
        }
      } else if((!$(this).hasClass("active") && other.hasClass("active")) || $(this).closest('tr').hasClass('success')) {
        //prevent clicking on unselected option or if the row is complete
        e.stopPropagation();
        e.preventDefault();
        return;
      } else {
        //selecting
        var self = this;
        if(checkbox.val()==="no") {
          launchPatientActionModal(local.selected, checkbox.closest('tr').children(':nth(2)').find('span').text(), getReason(patientId, ACTIONID), function(){
            editAction(patientId, ACTIONID, false, null, local.reason);
            $(self).removeClass("inactive");

            checkbox.attr("checked","checked");
            checkbox.parent().addClass("active");
            //unselect other
            other.removeClass("active").addClass("inactive");
            other.find("input[type=checkbox]").prop("checked", false);
            updateWelcomePage();
            wireUpTooltips();
          }), function(){

          };
          e.stopPropagation();
          e.preventDefault();
        }
        else {
          editAction(patientId, ACTIONID, true);
          $(this).removeClass("inactive");

          //unselect other
          other.removeClass("active").addClass("inactive");
          other.find("input[type=checkbox]").prop("checked", false);
        }
      }
		});

    updateWelcomePage();
  };

  var updateWelcomePage = function(){
    $('#team-task-panel').add('#individual-task-panel').find('.suggestion').each(function(){
			$(this).find('td').last().children().hide();
		});

    $('#team-task-panel').add('#individual-task-panel').find('.cr-styled input[type=checkbox]').each(function(){
      if(this.checked){
        $(this).parent().parent().parent().addClass('success');
      } else {
        $(this).parent().parent().parent().removeClass('success');
      }
    });

    $('#team-task-panel').add('#individual-task-panel').find('.btn-undo').each(function(){
      $(this).parent().parent().addClass('success');
    });

    //no class - user not yet agreed/disagreed - no background / muted text
    //active - user agrees - green background / normal text
    //success - user completed - green background / strikethrough text
    //danger - user disagrees - red background / strikethrough text
    $('#team-task-panel').add('#individual-task-panel').find('tr').each(function(){
      var self = $(this);
      var any = false;
      self.find('.btn-toggle input[type=checkbox]:checked').each(function(){
        any = true;
  			if(this.value==="yes"){
  				self.removeClass('danger');
  				self.addClass('active');
  				self.find('td').last().children().show();
          if(getObj().actions.team[self.data("id")] && getObj().actions.team[self.data("id")].history){
            var tool = $(this).closest('tr').hasClass('success') ? "" : getObj().actions.team[self.data("id")].history[0] + " - click again to cancel";
            $(this).parent().attr("title", tool).attr("data-original-title", tool).tooltip('fixTitle').tooltip('hide');
          } else {
            $(this).parent().attr("title", "You agreed - click again to cancel").tooltip('fixTitle').tooltip('hide');
          }
  			} else {
  				self.removeClass('active');
  				self.addClass('danger');
  				self.removeClass('success');
          if(getObj().actions.team[self.data("id")] && getObj().actions.team[self.data("id")].history){
            $(this).parent().attr("title", getObj().actions.team[self.data("id")].history[0] + " - click again to edit/cancel").tooltip('fixTitle').tooltip('hide');
          } else {
            $(this).parent().attr("title", "You disagreed - click again to edit/cancel").tooltip('fixTitle').tooltip('hide');
          }
  			}
      });
      if(self.find('.btn-toggle input[type=checkbox]:not(:checked)').length==1){
        self.find('.btn-toggle input[type=checkbox]:not(:checked)').parent().addClass("inactive").attr("title", "").attr("data-original-title", "").tooltip('fixTitle').tooltip('hide');
      }
      if(!any){
        self.removeClass('danger');
        self.removeClass('active');
        self.removeClass('success');

        self.find('.btn-toggle.btn-yes').attr("title", "Click to agree with this action").tooltip('fixTitle').tooltip('hide');
        self.find('.btn-toggle.btn-no').attr("title", "Click to disagree with this action").tooltip('fixTitle').tooltip('hide');
      }

      wireUpTooltips();
		});

    wireUpTooltips();
  };

  var createTestTrendPanel = function(pathwayId, pathwayStage, patientId){
    return createPanel(valueTrendPanel, {"pathway": local.monitored[pathwayId], "pathwayStage" : pathwayStage, "noHeader" : true});
  };

  var showTestTrendPanel = function(location, pathwayId, pathwayStage, patientId){
    createPanelShow(valueTrendPanel, location, {"pathway": local.monitored[pathwayId], "pathwayStage" : pathwayStage, "noHeader" : true});

    drawTrendChart(patientId, pathwayId);
  };

  var createMedicationPanel = function(pathwayStage, patientId) {
    var medications = local.data.patients[patientId].medications || [];
    return createPanel(medicationPanel, {"areMedications" : medications.length>0, "medications": medications, "pathwayStage" : pathwayStage, "noHeader" : true},{"medicationRow":$('#medication-row').html()});
  };

  var showMedicationPanel = function(location, pathwayStage, patientId) {
    var medications = local.data.patients[patientId].medications || [];
    createPanelShow(medicationPanel, location, {"areMedications" : medications.length>0, "medications": medications, "pathwayStage" : pathwayStage, "noHeader" : true},{"medicationRow":$('#medication-row').html()});
  };

  var removeDuplicates = function(array){
    var arrResult = {};
    var rtn = [];
    for (var i = 0; i < array.length; i++) {
        var item = array[i];
        arrResult[array[i]] = array[i];
    }
    for(var item in arrResult) {
        rtn.push(arrResult[item]);
    }
    return rtn;
  };

  var populateAllPatientPanel = function(){
    var pList=[], i,k, prop;
    for(k=0; k < local.diseases.length; k++){
      for(i in local.categories){
        for(prop in local.data[local.diseases[k].id][i].bdown){
          if(local.data[local.diseases[k].id][i].bdown.hasOwnProperty(prop)){
            pList = pList.concat(local.data[local.diseases[k].id][i].bdown[prop].patients);
          }
        }
      }
    }
    pList = removeDuplicates(pList);
    var patients = pList.map(function(patientId) {
			var ret = local.data.patients[patientId];
			ret.nhsNumber = local.patLookup ? local.patLookup[patientId] : patientId;
      ret.patientId = patientId;
      ret.items = []; //The fields in the patient list table
      ret.items.push(local.data.patients[patientId].breach.length);
			return ret;
		});

    var data = {"patients": patients, "n" : patients.length, "header-items" : [{"title" : "NHS no.", "isUnSortable" : true}, {"title" : "Standards missed", "isUnSortable" : true}]};

    data.patients.sort(function(a, b){
      if(a.items[0] === b.items[0]) {
        return 0;
      }
      var A = Number(a.items[0]);
      var B = Number(b.items[0]);
      if(isNaN(A) || isNaN(B)){
        A = a.items[0];
        B = b.items[0];
      }
      if(A > B) {
        return -1;
      } else if (A < B) {
        return 1;
      }
    });

		createPanelShow(patientList, patientsPanel, data, {"header-item" : $("#patient-list-header-item").html(), "item" : $('#patient-list-item').html()});

		$('#patients-placeholder').hide();

		setupClipboard($('.btn-copy'), true);

    wireUpTooltips();

    var c = patientsPanel.find('div.table-scroll').getNiceScroll();
    if(c && c.length>0){
      c.resize();
    } else {
      patientsPanel.find('div.table-scroll').niceScroll({
  			cursoropacitymin: 0.3,
  			cursorwidth: "7px",
  			horizrailenabled: false
  		});
    }
  };

  var wireUpTooltips = function(){
    $('[data-toggle="tooltip"]').tooltip({container: 'body', delay: { "show": 1000, "hide": 100 }});
    $('[data-toggle="lone-tooltip"]').tooltip({container: 'body', delay: { "show": 700, "hide": 100 }});
    $('[data-toggle="lone-tooltip"]').on('shown.bs.tooltip',function(e){
      $('[data-toggle="tooltip"]').not(this).tooltip('hide');
    });
  };

	var populatePatientPanel = function (pathwayId, pathwayStage, standard, subsection, sortField, sortAsc) {
    var pList=[], i,k, prop, header;
    patientsPanel.fadeOut(200, function(){
      $(this).fadeIn(200);
    });
    if(pathwayId && pathwayStage && standard && subsection) {
      pList = local.data[pathwayId][pathwayStage].standards[standard].opportunities.filter(function(val){return val.name===subsection;})[0].patients;
      header = local.data[pathwayId][pathwayStage].standards[standard].opportunities.filter(function(val){return val.name===subsection;})[0].desc;
    } else if(pathwayId && pathwayStage && subsection) {
      pList = local.data[pathwayId][pathwayStage].bdown[subsection].patients;
      header = local.data[pathwayId][pathwayStage].bdown[subsection].name;
    } else if(pathwayId && pathwayStage){
      for(prop in local.data[pathwayId][pathwayStage].bdown){
        if(local.data[pathwayId][pathwayStage].bdown.hasOwnProperty(prop)){
          pList = pList.concat(local.data[pathwayId][pathwayStage].bdown[prop].patients);
        }
      }
      header = local.data[pathwayId][pathwayStage].patientListHeader;
    } else if(pathwayId){
      for(i in local.categories){
        for(prop in local.data[pathwayId][i].bdown){
          if(local.data[pathwayId][i].bdown.hasOwnProperty(prop)){
            pList = pList.concat(local.data[pathwayId][i].bdown[prop].patients);
          }
        }
      }
    } else {
      for(k=0; k < local.diseases.length; k++){
        for(i in local.categories){
          for(prop in local.data[local.diseases[k].id][i].bdown){
            if(local.data[local.diseases[k].id][i].bdown.hasOwnProperty(prop)){
              pList = pList.concat(local.data[local.diseases[k].id][i].bdown[prop].patients);
            }
          }
        }
      }
    }
    pList = removeDuplicates(pList);
		var patients = pList.map(function(patientId) {
			var ret = local.data.patients[patientId];
			ret.nhsNumber = local.patLookup ? local.patLookup[patientId] : patientId;
      ret.patientId = patientId;
      ret.items = []; //The fields in the patient list table
			if(ret[local.data[local.pathwayId]["value-label"]]) {
        if(pathwayStage === local.categories.monitoring.name){
          ret.items.push(ret[local.data[local.pathwayId]["value-label"]][0][ret[local.data[local.pathwayId]["value-label"]][0].length-1]);
        }
        else{
          ret.items.push(ret[local.data[local.pathwayId]["value-label"]][1][ret[local.data[local.pathwayId]["value-label"]][1].length-1]);
        }
			} else {
        ret.items.push("?");
			}
			return ret;
		});

		var data = {"patients": patients, "n" : patients.length, "header" : header, "header-items" : [{"title" : "NHS no.", "isSorted":false, "direction":"sort-asc"}]};

    if(pathwayStage === local.categories.monitoring.name){
      data["header-items"].push({"title" : "Last BP Date", "isSorted":true, "direction":"sort-asc"});
    }
    else{
      data["header-items"].push({"title" : "Last SBP", "isSorted":true, "direction":"sort-asc"});
    }

    if(sortField === undefined) sortField = 1;
		if(sortField !== undefined) {
			data.patients.sort(function(a, b){
        if(sortField===0) { //NHS number
          if(a.nhsNumber === b.nhsNumber) {
  					return 0;
  				}

  				if(a.nhsNumber > b.nhsNumber) {
  					return sortAsc ? 1 : -1;
  				} else if (a.nhsNumber< b.nhsNumber) {
  					return sortAsc ? -1 : 1;
  				}
        } else {
        	if(a.items[sortField-1] === b.items[sortField-1]) {
  					return 0;
  				}

  				if(a.items[sortField-1] == "?") return 1;
  				if(b.items[sortField-1] == "?") return -1;

          var A = Number(a.items[sortField-1]);
          var B = Number(b.items[sortField-1]);
          if(isNaN(A) || isNaN(B)){
            A = a.items[sortField-1];
            B = b.items[sortField-1];
          }
  				if(A > B) {
  					return sortAsc ? 1 : -1;
  				} else if (A < B) {
  					return sortAsc ? -1 : 1;
  				}
        }
			});

      for(var i = 0; i < data["header-items"].length; i++) {
        if(i === sortField){
          data["header-items"][i].direction = sortAsc ? "sort-asc" : "sort-desc";
          data["header-items"][i].isAsc = sortAsc;
          data["header-items"][i].isSorted = true;
        } else {
          data["header-items"][i].isSorted = false;
        }
      }
			//data.direction = sortAsc ? "sort-asc" : "sort-desc";
			//data.isSorted = sortAsc;
		}

		createPanelShow(patientList, patientsPanel, data, {"header-item" : $("#patient-list-header-item").html(), "item" : $('#patient-list-item').html()});

		$('#patients-placeholder').hide();

		setupClipboard($('.btn-copy'), true);

    wireUpTooltips();

    var c = patientsPanel.find('div.table-scroll').getNiceScroll();
    if(c && c.length>0){
      c.resize();
    } else {
      patientsPanel.find('div.table-scroll').niceScroll({
  			cursoropacitymin: 0.3,
  			cursorwidth: "7px",
  			horizrailenabled: false
  		});
    }
	};

	var populatePatientPanelOk = function (pathwayId, pathwayStage, subsection, sortField, sortAsc) {
    var pList=[], i,k, prop, header;
    patientsPanel.fadeOut(200, function(){
      $(this).fadeIn(200);
    });

    pList = local.data[pathwayId][pathwayStage].patientsOk;
    header = local.data[pathwayId][pathwayStage].text.panelOkHeader.text;

    pList = removeDuplicates(pList);
		var patients = pList.map(function(patientId) {
			var ret = local.data.patients[patientId];
			ret.nhsNumber = local.patLookup ? local.patLookup[patientId] : patientId;
      ret.patientId = patientId;
      ret.items = []; //The fields in the patient list table
      ret.items.push(local.data.patients[patientId].breach ? local.data.patients[patientId].breach.length : 0);
			return ret;
		});
    var data = {"patients": patients, "n" : patients.length, "header-items" : [{"title" : "NHS no.", "isSorted":false, "direction":"sort-asc"}, {"title" : "Standards missed", "isSorted":true, "direction":"sort-desc"}]};

    if(sortField !== undefined) {
      data.patients.sort(function(a, b){
        if(sortField===0) { //NHS number
          if(a.nhsNumber === b.nhsNumber) {
            return 0;
          }

          if(a.nhsNumber > b.nhsNumber) {
            return sortAsc ? 1 : -1;
          } else if (a.nhsNumber< b.nhsNumber) {
            return sortAsc ? -1 : 1;
          }
        } else {
          if(a.items[sortField-1] === b.items[sortField-1]) {
            return 0;
          }

          var A = Number(a.items[sortField-1]);
          var B = Number(b.items[sortField-1]);
          if(isNaN(A) || isNaN(B)){
            A = a.items[sortField-1];
            B = b.items[sortField-1];
          }
          if(A > B) {
            return sortAsc ? 1 : -1;
          } else if (A < B) {
            return sortAsc ? -1 : 1;
          }
        }
      });

      for(var i = 0; i < data["header-items"].length; i++) {
        if(i === sortField){
          data["header-items"][i].direction = sortAsc ? "sort-asc" : "sort-desc";
          data["header-items"][i].isAsc = sortAsc;
          data["header-items"][i].isSorted = true;
        } else {
          data["header-items"][i].isSorted = false;
        }
      }
    }

		createPanelShow(patientList, patientsPanel, data, {"header-item" : $("#patient-list-header-item").html(), "item" : $('#patient-list-item').html()});

		$('#patients-placeholder').hide();

		setupClipboard($('.btn-copy'), true);

    wireUpTooltips();

    var c = patientsPanel.find('div.table-scroll').getNiceScroll();
    if(c && c.length>0){
      c.resize();
    } else {
      patientsPanel.find('div.table-scroll').niceScroll({
  			cursoropacitymin: 0.3,
  			cursorwidth: "7px",
  			horizrailenabled: false
  		});
    }
	};

  var addDisagreePersonalTeam = function(plans){
    for(var i = 0; i < plans.length; i++){
      if(plans[i].agree){
        plans[i].disagree = false;
      } else if (plans[i].agree === false){
        plans[i].disagree = true;
      }
    }
    return plans;
  };

  var addDisagree = function(suggestions, actions, id){
    for(var i = 0; i < suggestions.length; i++){
      if(actions[id][suggestions[i].id]){
        if(actions[id][suggestions[i].id].agree) {
          suggestions[i].agree = true;
          suggestions[i].disagree = false;
        } else if(actions[id][suggestions[i].id].agree===false){
          suggestions[i].agree = false;
          suggestions[i].disagree = true;
        }
        if(actions[id][suggestions[i].id].done) suggestions[i].done = actions[id][suggestions[i].id].done;
        else suggestions[i].done = false;
      }
    }
    return suggestions;
  };

  var mergeTeamStuff = function(suggestions){
    var teamActions = listActions();
    if(!teamActions["team"]) return suggestions;

    suggestions = addDisagree(suggestions, teamActions, "team");
    return suggestions;
  };

  var sortSuggestions = function(suggestions){
    suggestions.sort(function(a,b){
      if(a.agree && !a.done){
        if(b.agree && !b.done) return 0;
        return -1;
      } else if(!a.agree && !a.disagree){
        if(!b.agree && !b.disagree) return 0;
        if(b.agree && !b.done) return 1;
        return -1;
      } else if(a.agree && a.done){
        if(b.agree && b.done) return 0;
        if(b.disagree) return -1;
        return 1;
      } else {
        if(b.disagree) return 0;
        return 1;
      }
    });

    return suggestions;
  };

  var populateTeamSuggestedActionsPanel = function (){
    var suggestions = suggestionList(local.actionPlan[local.pathwayId].team);
    suggestions = sortSuggestions(mergeTeamStuff(suggestions));

		createPanelShow(suggestedPlanTemplate, suggestedPlanTeam, {"suggestions" : suggestions}, {"item" : $('#suggested-plan-item').html(), "chk" : $('#checkbox-template').html() });

		displayPersonalisedTeamActionPlan($('#personalPlanTeam'));
	};

	var populateSuggestedActionsPanel = function (pathwayStage){
		if(pathwayStage === local.categories.exclusions.name){
			suggestedPlanTeam.html('No team actions for excluded patients');
		} else if(pathwayStage === local.categories.diagnosis.name){
			suggestedPlanTeam.html('No team actions for these patients');
		} else {
			createPanelShow(suggestedPlanTemplate, suggestedPlanTeam, local.data[local.pathwayId][pathwayStage], {"item" : $('#suggested-plan-item').html(), "chk" : $('#checkbox-template').html() });

			displayPersonalisedIndividualActionPlan(pathwayStage, $('#personalPlanTeam'));

			createPanelShowvidualSapRows();
		}
	};

	var highlightOnHoverAndEnableSelectByClick = function(panelSelector) {
		panelSelector.children('div').removeClass('unclickable').on('mouseover',function(){
			$(this).removeClass('panel-default');
		}).on('mouseout',function(){
      $(this).addClass('panel-default');
    }).on('click', function(){
        // keep the link in the browser history
        history.pushState(null, null, '#main/'+local.pathwayId+'/'+$(this).data('stage')+'/yes');
        loadContent('#main/'+local.pathwayId+'/'+$(this).data('stage')+'/yes', true);
        // do not give a default action
        return false;
		});
	};

	/********************************
	* Charts - draw
	********************************/

	var drawTrendChart = function(patientId, pathwayId){
		destroyCharts(['chart-demo-trend']);
		if(!local.data.patients || !local.data.patients[patientId] || !local.data.patients[patientId][local.data[pathwayId]["value-label"]]) return;

		var chartOptions = {
			bindto: '#chart-demo-trend',
			data: {
        xs :{},
        classes : {},
				columns: local.data.patients[patientId][local.data[pathwayId]["value-label"]].slice()
			},
      zoom: {
          enabled: true
      },
      line: {
        connectNull: false
      },
			axis: {
				x: {
					type: 'timeseries',
					tick: {
  					format: '%d-%m-%Y',
  					count: 7,
  					culling: {
  						max: 3
  					}
					},
          max: new Date()
				}
			}
		};

    var maxValue = 0;
    var standardItems = [];

    for(var i = 1; i < chartOptions.data.columns.length; i++){
      chartOptions.data.xs[chartOptions.data.columns[i][0]] = "x";
      standardItems.push(chartOptions.data.columns[i][0]);

      for(var j = 1; j < chartOptions.data.columns[i].length; j++){
        if(parseFloat(chartOptions.data.columns[i][j]) > maxValue) maxValue = parseFloat(chartOptions.data.columns[i][j]);
      }
    }

    chartOptions.tooltip = {
        format: {
            value: function (value, ratio, id) {
                var text = standardItems.indexOf(id) > -1 ? value : "";
                return text;
            }
        }
    };

    var lines = null;
    var axisnum = 1;
		if(local.data.patients[patientId].contacts){
      for(var i = 0; i< local.data.patients[patientId].contacts.length; i++){
        chartOptions.data.classes[local.data.patients[patientId].contacts[i].text] = 'larger';
        if(!chartOptions.data.xs[local.data.patients[patientId].contacts[i].text]) {
          chartOptions.data.xs[local.data.patients[patientId].contacts[i].text] = "x"+axisnum;
          chartOptions.data.columns.push(["x"+axisnum,local.data.patients[patientId].contacts[i].value]);
          chartOptions.data.columns.push([local.data.patients[patientId].contacts[i].text, (maxValue*1.1).toString()]);
          axisnum++;
        } else {
          var axis = chartOptions.data.xs[local.data.patients[patientId].contacts[i].text];
          for(var j = 1; j <chartOptions.data.columns.length;j++ ){
            if(chartOptions.data.columns[j][0]===axis) {
              chartOptions.data.columns[j].push(local.data.patients[patientId].contacts[i].value);
            } else if(chartOptions.data.columns[j][0]===local.data.patients[patientId].contacts[i].text){
              chartOptions.data.columns[j].push((maxValue*1.1).toString());
            }
          }
        }
      }
    }

    var obj = getObj();
    var patientEvents = obj.events.filter(function(val){
      return val.id === patientId;
    });
    if(patientEvents.length>0){

      for(var i = 0; i < patientEvents.length; i++){
        chartOptions.data.classes[patientEvents[i].name] = 'larger';
        if(!chartOptions.data.xs[patientEvents[i].name]) {
          chartOptions.data.xs[patientEvents[i].name] = "x"+axisnum;
          chartOptions.data.columns.push(["x"+axisnum,patientEvents[i].date.substr(0,10)]);
          chartOptions.data.columns.push([patientEvents[i].name, (maxValue*1.1).toString()]);
          axisnum++;
        } else {
          var axis = chartOptions.data.xs[patientEvents[i].name];
          for(var j = 1; j <chartOptions.data.columns.length;j++ ){
            if(chartOptions.data.columns[j][0]===axis) {
              chartOptions.data.columns[j].push(patientEvents[i].date.substr(0,10));
            } else if(chartOptions.data.columns[j][0]===patientEvents[i].name){
              chartOptions.data.columns[j].push((maxValue*1.1).toString());
            }
          }
        }
      }
    }

    //draw charts in separate thread and with delay to stop sluggish appearance
    setTimeout(function(){
      local.charts['chart-demo-trend'] = c3.generate(chartOptions);
    }, 1);
	};

	var selectPieSlice = function (chart, d){
		local.chartClicked=true;
		$('#' + chart + ' path.c3-bar').attr('class', function(index, classNames) {
			return classNames + ' _unselected_';
		});
		local.charts[chart].select([d.id], [d.index], true);

    farRightPanel.fadeOut(200);
	};

	var destroyCharts = function(charts){
		for(var i = 0 ; i<charts.length; i++){
			if(local.charts[charts[i]]) {
				local.charts[charts[i]].destroy();
				delete local.charts[charts[i]];
			}
		}
	};

	var showOverviewPanels = function(){
		switchTo221Layout();

		showPanel(local.categories.diagnosis.name, topLeftPanel, true);
		showPanel(local.categories.monitoring.name, topRightPanel, true);
		showPanel(local.categories.treatment.name, bottomLeftPanel, true);
		showPanel(local.categories.exclusions.name, bottomRightPanel, true);

    wireUpTooltips();
	};

  var updateTeamSapRows = function(){
    suggestedPlanTeam.add('#personalPlanTeam').find('.suggestion').each(function(){
			$(this).find('td').last().children().hide();
		});

    suggestedPlanTeam.add('#personalPlanTeam').find('.cr-styled input[type=checkbox]').each(function(){
      if(this.checked){
        $(this).parent().parent().parent().addClass('success');
      } else {
        $(this).parent().parent().parent().removeClass('success');
      }
    });

    suggestedPlanTeam.add('#personalPlanTeam').find('.btn-undo').each(function(){
      $(this).parent().parent().addClass('success');
    });

    //no class - user not yet agreed/disagreed - no background / muted text
    //active - user agrees - green background / normal text
    //success - user completed - green background / strikethrough text
    //danger - user disagrees - red background / strikethrough text
    suggestedPlanTeam.add('#personalPlanTeam').find('tr').each(function(){
      var self = $(this);
      var any = false;
      self.find('.btn-toggle input[type=checkbox]:checked').each(function(){
        any = true;
  			if(this.value==="yes"){
  				self.removeClass('danger');
  				self.addClass('active');
  				self.find('td').last().children().show();
          if(getObj().actions.team[self.data("id")].history){
            var tool = $(this).closest('tr').hasClass('success') ? "" : getObj().actions.team[self.data("id")].history[0] + " - click again to cancel";
            $(this).parent().attr("title", tool).attr("data-original-title", tool).tooltip('fixTitle').tooltip('hide');
          } else {
            $(this).parent().attr("title", "You agreed - click again to cancel").tooltip('fixTitle').tooltip('hide');
          }
  			} else {
  				self.removeClass('active');
  				self.addClass('danger');
  				self.removeClass('success');
          if(getObj().actions.team[self.data("id")] && getObj().actions.team[self.data("id")].history){
            $(this).parent().attr("title", getObj().actions.team[self.data("id")].history[0] + " - click again to edit/cancel").tooltip('fixTitle').tooltip('hide');
          } else {
            $(this).parent().attr("title", "You disagreed - click again to edit/cancel").tooltip('fixTitle').tooltip('hide');
          }
  			}
      });
      if(self.find('.btn-toggle input[type=checkbox]:not(:checked)').length==1){
        self.find('.btn-toggle input[type=checkbox]:not(:checked)').parent().addClass("inactive").attr("title", "").attr("data-original-title", "").tooltip('fixTitle').tooltip('hide');
      }
      if(!any){
        self.removeClass('danger');
        self.removeClass('active');
        self.removeClass('success');

        self.find('.btn-toggle.btn-yes').attr("title", "Click to agree with this action").tooltip('fixTitle').tooltip('hide');
        self.find('.btn-toggle.btn-no').attr("title", "Click to disagree with this action").tooltip('fixTitle').tooltip('hide');
      }

      wireUpTooltips();
		});

    wireUpTooltips();
  };

  var updateIndividualSapRows = function(){
    $('#advice-list').add('#personalPlanIndividual').find('.suggestion').each(function(){
			$(this).find('td').last().children().hide();
		});

    $('#advice-list').add('#personalPlanIndividual').find('.cr-styled input[type=checkbox]').each(function(){
      if(this.checked){
        $(this).parent().parent().parent().addClass('success');
      } else {
        $(this).parent().parent().parent().removeClass('success');
      }
    });

    $('#advice-list').add('#personalPlanIndividual').find('.btn-undo').each(function(){
      $(this).parent().parent().addClass('success');
    });

    //no class - user not yet agreed/disagreed - no background / muted text
    //active - user agrees - green background / normal text
    //success - user completed - green background / strikethrough text
    //danger - user disagrees - red background / strikethrough text

    $('#advice-list').add('#personalPlanIndividual').find('tr').each(function(){
      var self = $(this);
      var any = false;
      self.find('.btn-toggle input[type=checkbox]:checked').each(function(){
        any = true;
  			if(this.value==="yes"){
  				self.removeClass('danger');
  				self.addClass('active');
  				self.find('td').last().children().show();
          if(getObj().actions[local.patientId][self.data("id")].history){
            var tool = $(this).closest('tr').hasClass('success') ? "" : getObj().actions[local.patientId][self.data("id")].history[0] + " - click again to cancel";
            $(this).parent().attr("title", tool).attr("data-original-title", tool).tooltip('fixTitle').tooltip('hide');
          } else {
            $(this).parent().attr("title", "You agreed - click again to cancel").tooltip('fixTitle').tooltip('hide');
          }
  			} else {
  				self.removeClass('active');
  				self.addClass('danger');
          self.removeClass('success');
          if(getObj().actions[local.patientId][self.data("id")] && getObj().actions[local.patientId][self.data("id")].history){
            $(this).parent().attr("title", getObj().actions[local.patientId][self.data("id")].history[0] + " - click again to edit/cancel").tooltip('fixTitle').tooltip('hide');
          } else {
            $(this).parent().attr("title", "You disagreed - click again to edit/cancel").tooltip('fixTitle').tooltip('hide');
          }
  			}
      });
      if(self.find('.btn-toggle input[type=checkbox]:not(:checked)').length==1){
        self.find('.btn-toggle input[type=checkbox]:not(:checked)').parent().addClass("inactive").attr("title", "").attr("data-original-title", "").tooltip('fixTitle').tooltip('hide');
      }
      if(!any){
        self.removeClass('danger');
        self.removeClass('active');
        self.removeClass('success');

        self.find('.btn-toggle.btn-yes').attr("title", "Click to agree with this action").tooltip('fixTitle').tooltip('hide');
        self.find('.btn-toggle.btn-no').attr("title", "Click to disagree with this action").tooltip('fixTitle').tooltip('hide');
      }

      wireUpTooltips();
		});
    wireUpTooltips();
  };

  var suggestionList = function (ids){
    return ids.map(function(val){
      return {"id" : val, "text" : local.actionText[val].text};
    });
  };

  var mergeIndividualStuff = function(suggestions, patientId){
    var actions = listActions();
    if(!actions[patientId]) return suggestions;

    for(var i = 0; i < suggestions.length; i++){
      if(actions[patientId][suggestions[i].id]){
        if(actions[patientId][suggestions[i].id].agree) {
          suggestions[i].agree = true;
        } else if(actions[patientId][suggestions[i].id].agree===false){
          suggestions[i].disagree = true;
        }
        if(actions[patientId][suggestions[i].id].done) suggestions[i].done = actions[patientId][suggestions[i].id].done;
      }
    }
    return suggestions;
  };

	var populateIndividualSuggestedActions = function (patientId, pathwayId, pathwayStage, isMultiple) {
		var data = {"nhsNumber" : local.patLookup ? local.patLookup[patientId] : patientId, "patientId" : patientId, "isMultiple" : isMultiple};

    var subsection = local.data.patients[patientId].breach.filter(function(v) {return v.pathwayId === pathwayId && v.pathwayStage === pathwayStage;})[0].subsection;

    data.suggestions = sortSuggestions(mergeIndividualStuff(suggestionList(local.data[pathwayId][pathwayStage].bdown[subsection].suggestions), patientId));
    data.section = {
      "name" : local.data[pathwayId][pathwayStage].bdown[subsection].name,
      "agree" : getPatientAgree(pathwayId, pathwayStage, patientId, "section") === true,
      "disagree" : getPatientAgree(pathwayId, pathwayStage, patientId, "section") === false,
    }
    data.category = {
      "name" : local.data.patients[patientId].category,
      "agree" : getPatientAgree(pathwayId, pathwayStage, patientId, "category") === true,
      "disagree" : getPatientAgree(pathwayId, pathwayStage, patientId, "category") === false,
    }

		$('#advice-placeholder').hide();
		$('#advice').show();

		createPanelShow(individualPanel, $('#advice-list'), data, {"chk" : $('#checkbox-template').html() });

    //Wire up multiple patient alert
    if(isMultiple){
      $('#advice-list .alert.clickable').off('click').on('click', function(){
        displaySelectedPatient($(this).data('id'));
      });
    }

    //Wire up any clipboard stuff in the suggestions
    $('#advice-list').find('span:contains("[COPY")').each(function(){
      var html = $(this).html();
      $(this).html(html.replace(/\[COPY:([^\]]*)\]/g,'$1 <button type="button" data-clipboard-text="$1" data-content="Copied" data-toggle="tooltip" data-placement="top" title="Copy $1 to clipboard." class="btn btn-xs btn-default btn-copy"><span class="fa fa-clipboard"></span></button>'));
    });

    $('#advice-list').find('span:contains("[MED-SUGGESTION")').each(function(){
      var html = $(this).html();
      var suggestion = Math.random() <0.33 ? "Increase Ramipril to 10mg per day" : (Math.random() < 0.5 ? "Consider adding an ACE inhibior" : "Consider adding a thiazide-like diuretic");
      $(this).html(html.replace(/\[MED\-SUGGESTION\]/g,suggestion));
    });


		setupClipboard( $('.btn-copy'), true );

		displayPersonalisedIndividualActionPlan(patientId, $('#personalPlanIndividual'));
	};

	var displayPersonalisedTeamActionPlan = function(parentElem) {
		var plans = sortSuggestions(addDisagreePersonalTeam(listPlans("team", local.pathwayId)));

		createPanelShow(actionPlanList, parentElem, {"hasSuggestions" : plans && plans.length > 0, "suggestions" : plans}, {"action-plan": $('#action-plan').html(), "action-plan-item": $('#action-plan-item').html(), "chk" : $('#checkbox-template').html() });

    updateTeamSapRows();
	};

	var displayPersonalisedIndividualActionPlan = function(id, parentElem) {
		var plans = sortSuggestions(addDisagreePersonalTeam(listPlans(id)));

		createPanelShow(actionPlanList, parentElem, {"hasSuggestions" : plans && plans.length > 0, "suggestions" : plans}, {"action-plan": $('#action-plan').html(), "action-plan-item": $('#action-plan-item').html(), "chk" : $('#checkbox-template').html() });

    updateIndividualSapRows();
	};

	var displaySelectedPatient = function(id){
    var nhs = local.patLookup ? local.patLookup[id] : id;

    /*if(local.data.patients[id].breach.length===1){
      //only one match so can go straight to that page

      local.pathwayId = local.data.patients[id].breach[0].pathwayId;
      var pathwayStage = local.data.patients[id].breach[0].pathwayStage;
      var subsection = local.data.patients[id].breach[0].subsection;

      // keep the link in the browser history
      history.pushState(null, null, '#main/'+local.pathwayId+'/'+pathwayStage);
      loadContent('#main/'+local.pathwayId+'/'+pathwayStage, true);

      populatePatientPanel(local.pathwayId, pathwayStage, subsection);
      local.subselected = subsection;

      showPathwayStageView(local.pathwayId, pathwayStage);
      showPathwayStagePatientView(id, local.pathwayId, local.selected, false);

      $('.list-item').removeClass('highlighted');
      $('.list-item:has(button[data-clipboard-text=' + nhs +'])').addClass('highlighted');
    }
    else {*/
      // keep the link in the browser history
    history.pushState(null, null, '#patients/'+id);
    loadContent('#patients/'+id, true);

    $('.list-item').removeClass('highlighted');
    $('.list-item:has(button[data-clipboard-text=' + nhs +'])').addClass('highlighted');
    //}

    //scroll to patients
    $('#patients').find('div.table-scroll').getNiceScroll().doScrollPos(0,$('#patients td:contains(' + nhs + ')').position().top-140);
	};

	var showPage = function (page) {
    if(local.page === page) return;
		local.page = page;
		$('.page').hide();
		$('#' + page).show();

		if (page !== 'main-dashboard') {
			hideSidePanel();
      hideHeaderBarItems();
		}
	};

  /********************************
	* Modals
	********************************/
  var showSaved = function(){
    $("#saved-message").hide().toggleClass("in").fadeIn(300);
    window.setTimeout(function(){
      $("#saved-message").fadeOut(300, function(){
        $(this).toggleClass("in");
      });
    }, 2000);
  };

  var launchModal = function(data, label, value, reasonText, callbackOnSave, callbackOnCancel){
    var template = $('#modal-why').html();
    Mustache.parse(template);   // optional, speeds up future uses

    var reasonTemplate = $('#modal-why-item').html();
    Mustache.parse(reasonTemplate);

    var rendered = Mustache.render(template, data, {"item" : reasonTemplate});
    $('#modal').html(rendered);

    if(reasonText){
      $('#modal textarea').val(reasonText);
    }
    local.modalSaved = false;

    $('#modal .modal').off('submit','form').on('submit', 'form', {"label" : label}, function(e){
      if(!e.data.label) e.data.label = "team";
      var reason = $('input:radio[name=reason]:checked').val();
      var reasonText = $('#modal textarea').val();

      recordFeedback(local.pathwayId, e.data.label, value, reason, reasonText)

      local.modalSaved = true;

      e.preventDefault();
      $('#modal .modal').modal('hide');
    }).modal();

    $('#modal').off('hidden.bs.modal').on('hidden.bs.modal', {"label" : label}, function(e) {
      if(local.modalSaved) {
        local.modalSaved = false;
        if(callbackOnSave) callbackOnSave();
        //showSaved();
      } else {
        //uncheck as cancelled. - but not if value is empty as this unchecks everything - or if already checked
        if(callbackOnCancel) callbackOnCancel();
        //if(value !== "") $('tr:contains('+value+')').find(".btn-toggle input[type=checkbox]:checked").click();
      }
    });
  };

  var launchTeamModal = function(label, value, reason, callbackOnSave, callbackOnCancel){
    var reasons = [{"reason":"We've already done this","value":"done"},{"reason":"It wouldn't work","value":"nowork"},{"reason":"Other","value":"else"}];
    if(reason && reason.reason) {
      for(var i = 0; i < reasons.length; i++) {
        if(reasons[i].reason === reason.reason) {
          reasons[i].checked = true;
          break;
        }
      }
    }
    launchModal({"header" : "Disagree with a suggested action", "item": value, "placeholder":"Enter free-text here...", "reasons" : reasons},label, value, reason ? reason.reasonText : null, callbackOnSave, callbackOnCancel);
  };

  var launchPatientModal = function(pathwayId, pathwayStage, label, value, justtext){
    var reasons = [], header;
    if(justtext!==true && (pathwayStage===local.categories.monitoring.name || pathwayStage===local.categories.treatment.name)) {
      if(pathwayStage===local.categories.monitoring.name) reasons.push({"reason":"Has actually already been monitored","value":"alreadymonitored"});
      else if(pathwayStage===local.categories.treatment.name) reasons.push({"reason":"Is actually treated to target","value":"treated"});
      reasons.push({"reason":"Should be excluded – please see the suggested way on how to do this below in the 'suggested actions panel'","value":"shouldexclude"});
      var breach = local.data.patients[local.patientId].breach.filter(function(val){return val.pathwayId === pathwayId && val.pathwayStage === pathwayStage;})[0];
      for(var prop in local.data[pathwayId][pathwayStage].bdown) {
        if(breach.subsection !== prop) {
          reasons.push({"reason": "Should be in the '" + prop + "' group", "value": "shouldbe_"+prop.replace(/\s+/g, '')});
        }
      }
      reasons.push({"reason":"Something else","value":"else"});
    }
    if(justtext){
      header = "Disagree with quality standard missed";
    } else {
      header = "Disagree with improvement opportunity";
    }
    launchModal({"header" : header, "item" : value, "placeholder":"Provide more information here...", "reasons" : reasons},label, value);
  };

  var launchPatientActionModal = function(label, value, reason, callbackOnSave, callbackOnCancel){
    var reasons = [{"reason":"Already done this","value":"done"},{"reason":"Wouldn't work","value":"nowork"},{"reason":"Something else","value":"else"}];
    if(reason && reason.reason) {
      for(var i = 0; i < reasons.length; i++) {
        if(reasons[i].reason === reason.reason) {
          reasons[i].checked = true;
          break;
        }
      }
    }
    launchModal({"header" : "Disagree with a suggested action", "item": value, "placeholder":"Provide more information here...", "reasons" : reasons},label, value, reason ? reason.reasonText : null, callbackOnSave, callbackOnCancel);
  };

  /*******************
  * Utility functions
  ********************/

	var getObj = function(){
    var obj = JSON.parse(localStorage.bb);
    if(!obj.actions) {
      obj.actions = {};
      setObj(obj);
    }
    if(!obj.plans) {
      obj.plans = {};
      setObj(obj);
    }
    if(!obj.agrees) {
      obj.agrees = {};
      setObj(obj);
    }
    if(!obj.feedback) {
      obj.feedback = [];
      setObj(obj);
    }
    if(!obj.events) {
      obj.events = [];
      setObj(obj);
    }
		return obj;
	};

	var setObj = function(obj){
		localStorage.bb = JSON.stringify(obj);
	};

	var setupClipboard = function(selector, destroy) {
		if(destroy)	ZeroClipboard.destroy(); //tidy up

		var client = new ZeroClipboard(selector);

		client.on( 'ready', function() {
			client.on( 'aftercopy', function(event) {
				console.log('Copied text to clipboard: ' + event.data['text/plain']);
        $(event.target).tooltip('hide');
        $(event.target).popover({
          trigger: 'manual',
          template: '<div class="popover" role="tooltip"><div class="arrow"></div><div class="popover-content"></div></div>',
          delay: {show:500, hide:500}
        });
        clearTimeout(local.tmp);
        $(event.target).popover('show');
        local.tmp = setTimeout(function(){$(event.target).popover('hide');}, 600);
			});
		});
	};

	var exportPlan = function(what){
		var doc = new jsPDF(), margin = 20, verticalOffset = margin;

		var addHeading = function(text, size){
			if(verticalOffset > 270) {
				doc.addPage();
				verticalOffset = margin;
			}
			doc.setFontSize(size).text(margin, verticalOffset+10, text);
			verticalOffset+=15;
		};

		var addLine = function(text){
			var lines = doc.setFontSize(11).splitTextToSize(text, 170);
			if(verticalOffset +lines.length*10 > 280) {
				doc.addPage();
				verticalOffset = margin;
			}
			doc.text(margin, verticalOffset+5, lines);
			verticalOffset+=lines.length*7;
		};

		//create doctype
		var data = getObj(),i,j,mainId,suggs;


		addHeading("Action Plan",24);
		//Measured
		addHeading("Monitoring",20);

    addLine(what);
    addLine(what);
    addLine(what);

	/*	var internalFunc = function(el) {
      var k;
			if(data.plans.individual[el] || data.actions[el]) {
        addLine("Patient "+ el +":");
        if(data.plans.individual[el]) {
          for(k =0; k < data.plans.individual[el].length; k++){
            if(!data.plans.individual[el][k].done){
              addLine(data.plans.individual[el][k].text);
            }
          }
  			}
        if(data.actions[el]) {
          var pathSec = local.data[local.pathwayId].patients[el].pathwayStage;
          var pathSub = local.data[local.pathwayId].patients[el].subsection;
          for(k =0; k < Math.max(data.actions[el].agree.length, data.actions[el].done.length); k++){
            if(data.actions[el].done.length>k && data.actions[el].done[k] ){
              //Completed so ignore
            } else if(data.actions[el].agree.length>k && data.actions[el].agree[k] ){
              addLine(local.actionPlan[pathSec].individual[pathSub][k].text);
            }
          }   //
  			}
      }
		};

    addHeading("Team plan",14);
    suggs = local.data[local.pathwayId].monitoring.suggestions;
    for(i=0; i<suggs.length; i++){
      if(data.actions.monitoring && data.actions.monitoring.done && data.actions.monitoring.done.length>i && data.actions.monitoring.done[i] ){
        //Completed so ignore
      } else if(data.actions.monitoring && data.actions.monitoring.agree && data.actions.monitoring.agree.length>i && data.actions.monitoring.agree[i] ){
        addLine(suggs[i].text);
      }
    }

    if(data.plans.team.monitoring && data.plans.team.monitoring.filter(function(i,v){if(!v.done) return true; else return false;}).length>0){
      addHeading("Custom team plan",14);
      for(i=0; i < data.plans.team.monitoring.length; i++){
          if(!data.plans.team.monitoring[i].done){
            addLine(data.plans.team.monitoring[i].text);
          }
      }
    }

		addHeading("Custom individual plans",14);
    for(i=0; i< local.data[local.pathwayId].monitoring.breakdown.length; i++){
			mainId = local.data[local.pathwayId].monitoring.breakdown[i][0];
		  local.data[local.pathwayId].monitoring.bdown[mainId].patients.forEach(internalFunc);
    }

    addHeading("Treatment",20);

    addHeading("Team plan",14);
    suggs = local.data[local.pathwayId].treatment.suggestions;
    for(i=0; i<suggs.length; i++){
      if(data.actions.treatment && data.actions.treatment.done && data.actions.treatment.done.length>i && data.actions.treatment.done[i] ){
        //Completed so ignore
      } else if(data.actions.treatment && data.actions.treatment.agree && data.actions.treatment.agree.length>i && data.actions.treatment.agree[i] ){
        addLine(suggs[i].text);
      }
    }

    if(data.plans.team.treatment && data.plans.team.treatment.filter(function(i,v){if(!v.done) return true; else return false;}).length>0){
      addHeading("Custom team plan",14);
      for(i=0; i < data.plans.team.treatment.length; i++){
          if(!data.plans.team.treatment[i].done){
            addLine(data.plans.team.treatment[i].text);
          }
      }
    }

		addHeading("Custom individual plans",14);
    for(i=0; i< local.data[local.pathwayId].monitoring.breakdown.length; i++){
			mainId = local.data[local.pathwayId].monitoring.breakdown[i][0];
		  local.data[local.pathwayId].monitoring.bdown[mainId].patients.forEach(internalFunc);
    }*/

		//trigger download
		doc.save();
	};

  /********************************
	* Page setup
	********************************/

	var onSelected = function($e, nhsNumberObject) {
		//Hide the suggestions panel
		$('#search-box').find('.tt-dropdown-menu').css('display', 'none');

    clearBox();

		displaySelectedPatient(nhsNumberObject.id);
	};

  var clearBox = function(){
    //Clear the patient search box
    $('.typeahead').typeahead('val', '');
  };

  var clearNavigation = function(){
    $("aside.left-panel nav.navigation > ul > li > ul").slideUp(300);
    $("aside.left-panel nav.navigation > ul > li").removeClass('active');
  };

  var showNavigation = function(list, idx, parent){
    if(local.elements.navigation){

      if(idx===-1){
        clearNavigation();
        $('aside a[href="#welcome"]:first').closest('li').addClass('active');
      } else if (idx >= list.length){
        clearNavigation();
        $('aside a[href="#patients"]').closest('li').addClass('active');
      } else if(!$('aside a[href="#' + list[idx].link + '"]:first').closest('li').hasClass('active')){
        clearNavigation();
        //set active
        $('aside a[href="#' + list[idx].link + '"]').next().slideToggle(300);
        $('aside a[href="#' + list[idx].link + '"]').closest('li').addClass('active');
      }

      return;
    }

    var template = $('#pathway-picker').html();
    var itemTemplate = $('#pathway-picker-item').html();
    Mustache.parse(template);
    Mustache.parse(itemTemplate);

    list = list.slice();
    list[0].isBreakAbove = true;
    for(var i = 0; i < list.length; i++){
      list[i].hasSubItems = true;
    }
    list.unshift({"link":"welcome", "faIcon":"fa-home", "name":"Home"});
    list.push({"link":"patients", "faIcon":"fa-users", "name":"All Patients", "isBreakAbove":true});

    list.map(function(v, i, arr){ v.isSelected = i===idx+1; return v; });

    var renderedBefore = Mustache.render(template, {"items": list}, {"item": itemTemplate, "subItem":$('#pathway-picker-sub-item').html()});
    $('#aside-toggle nav:first').html(renderedBefore);

    $('.user').on('click', function(){
      loadContent('#welcome');
    });

    local.elements.navigation = true;
  };

  var loadContent = function(hash, isPoppingState){
    var i;
    if(!isPoppingState) {
      window.location.hash = hash;
    }

    if(hash === ''){
      showPage('login');
      $('html').removeClass('scroll-bar');
    } else {
      $('html').addClass('scroll-bar');
      var urlBits = hash.split('/');
      if(urlBits[0]==="#main") {
        var pathwayId = urlBits[1];
        var pathwayStage = urlBits[2];
        var yesPeople = urlBits[3] !== "no";
        var standard = urlBits[4];

        if(pathwayStage && local.page !== 'main-dashboard'){
          $('.page').hide();
          $('#main-dashboard').show();

          showSidePanel();
          showOverviewPanels();
          showHeaderBarItems();
        }

        if(pathwayStage) {
          if(yesPeople){
            showPathwayStageViewOk(pathwayId, pathwayStage);
          } else {
            showPathwayStageView(pathwayId, pathwayStage, standard);
          }
        } else {
          showOverview(pathwayId);
        }

        wireUpTooltips();

      } else if (urlBits[0] === "#help") {
        showPage('help-page');

        showSidePanel();
        showHeaderBarItems();
        //hideAllPanels();
        showNavigation(local.diseases, -1, $('#help-page'));
        clearNavigation();
      } else if (urlBits[0]==="#patients") {

        var patientId = urlBits[1];
        var pathwayId = urlBits[2];

        showAllPatientView(patientId, true);

        wireUpTooltips();

        if(patientId) {
          var nhs = local.patLookup ? local.patLookup[patientId] : patientId;
          $('#patients').find('div.table-scroll').getNiceScroll().doScrollPos(0,$('#patients td:contains(' + nhs + ')').position().top-140);
          $('#patients').find('tr:contains(' + nhs + ')').addClass("highlighted");
        }
      } else if (urlBits[0] === "#welcome") {
        showPage('welcome');

        showSidePanel();
        showHeaderBarItems();
        //hideAllPanels();
        showNavigation(local.diseases, -1, $('#welcome'));

        $('#welcome-tabs li').removeClass('active');
        $('#outstandingTasks').closest('li').addClass('active');

        populateWelcomeTasks();


      } else {
        //if screen not in correct segment then select it
        alert("shouldn't get here");
        var pathwayStage = hash.substr(1);

        showPathwayStageView(pathwayStage);

        wireUpTooltips();
      }
    }
  };

  var populateWelcomeTasks = function(complete){

    //add tasks
    var teamTasks = [];
    var individualTasks = [];

    //Add the team tasks
    for(var k in listActions("team")){
      if(listActions("team")[k].agree && ( (!listActions("team")[k].done && !complete) || (listActions("team")[k].done && complete))){
        teamTasks.push({"pathway": "N/A", "task": local.actionText[listActions("team")[k].id].text, "data":listActions("team")[k].id, "tpId":"team", "agree" :true, "done": complete});
      }
    }

    //Add the user added team tasks
    for(var k in listPlans("team")){
      if((!listPlans("team")[k].done && !complete) || (listPlans("team")[k].done && complete)){
        teamTasks.push({"canEdit":true,"pathway": local.pathwayNames[listPlans("team")[k].pathwayId], "pathwayId":listPlans("team")[k].pathwayId, "task": listPlans("team")[k].text, "data": listPlans("team")[k].id, "agree" :listPlans("team")[k].agree, "disagree" : listPlans("team")[k].agree===false, "done": complete});
      }
    }

    //Add individual
    for(var k in listActions()){
      if(k==="team") continue;
      for(var l in listActions()[k]){
        if(local.actionText[l] && listActions()[k][l].agree && ( (!listActions()[k][l].done && !complete) || (listActions()[k][l].done && complete))){
          individualTasks.push({"pathway": "N/A", "patientId":k, "task": local.actionText[l].text, "pathwayId":listPlans()[k][l].pathwayId, "data":l, "tpId":k, "agree" :true, "done": complete});
        }
      }
    }

    //Add custom individual
    for(var k in listPlans()){
      if(k==="team") continue;
      for(var l in listPlans()[k]){
        if(listPlans()[k][l].text && (!listPlans()[k][l].done && !complete) || (listPlans()[k][l].done && complete)){
          individualTasks.push({"canEdit":true,"pathway": local.pathwayNames[listPlans()[k][l].pathwayId], "pathwayId":listPlans()[k][l].pathwayId, "patientId":k, "tpId":k, "task": listPlans()[k][l].text, "data":l, "agree" :true, "done": complete});
        }
      }
    }

    var listTemplate = $('#welcome-task-list').html();
    Mustache.parse(listTemplate);
    $('#welcome-tab-content').html(Mustache.render(listTemplate));

    var addTemplate = $('#action-plan').html();
    Mustache.parse(addTemplate);
    var rendered = Mustache.render(addTemplate);
    $('#team-add-plan').html(rendered);

    var template = $('#welcome-task-items').html();
    var itemTemplate = $('#welcome-task-item').html();
    Mustache.parse(template);
    Mustache.parse(itemTemplate);

    $('#team-add-plan').off('click').on('click', '.add-plan', function(){
      var plan = $(this).parent().parent().find('textarea').val();
      var planId = recordPlan("team", plan, "custom");
      var itemTemp
      $('#team-task-panel').find('table tbody').append(Mustache.render(itemTemplate, {"pathway": "N/A", "task": plan, "data": planId, "agree" :null, "done": null}, {"chk" : $('#checkbox-template').html()}));
    });

    rendered = Mustache.render(template, {"tasks": teamTasks, "hasTasks": teamTasks.length>0}, {"task-item" : itemTemplate, "chk" : $('#checkbox-template').html()});
    $('#team-task-panel').children().not(":first").remove();
    $('#team-task-panel').append(rendered);

    rendered = Mustache.render(template, {"tasks": individualTasks, "isPatientTable":true, "hasTasks": individualTasks.length>0}, {"task-item" : itemTemplate, "chk" : $('#checkbox-template').html()});
    $('#individual-task-panel').children().not(":first").remove();
    $('#individual-task-panel').append(rendered);

    wireUpWelcomePage();
  };

  var wireUpSearchBox = function () {
    if(local.states) {
      local.states.clearPrefetchCache();
    }

    local.states = new Bloodhound({
      datumTokenizer: Bloodhound.tokenizers.obj.whitespace('value'),
      queryTokenizer: Bloodhound.tokenizers.whitespace,
      local: $.map(local.data.patientArray, function(state) { return { id: state, value: local.patLookup ? local.patLookup[state] : state }; })
    });

    local.states.initialize(true);

    $('#search-box').find('.typeahead').typeahead('destroy');
    $('#search-box').find('.typeahead').typeahead(
      {hint: true, highlight: true, minLength: 1, autoselect: true},
      {name: 'patients', displayKey: 'value', source: local.states.ttAdapter(), templates: {
        empty: [
          '<div class="empty-message">',
            '&nbsp; &nbsp; No matches',
          '</div>'
        ].join('\n')}
      }
    ).on('typeahead:selected', onSelected)
    .on('typeahead:autocompleted', onSelected)
    .on('typeahead:closed', clearBox);

    $('#searchbtn').on('mousedown', function(){
      var val = $('.typeahead').eq(0).val();
      onSelected(null, {"id": val});
    });
  };

  var preWireUpPages = function() {
		showPage('login');

    //Every link element stores href in history
    $(document).on('click', 'a.history', function() {
      // keep the link in the browser history
      history.pushState(null, null, this.href);
      loadContent(location.hash, true);
      // do not give a default action
      return false;
    });

    //Called when the back button is hit
    $(window).on('popstate', function(e) {
      loadContent(location.hash, true);
    });

		//Templates
		monitoringPanel = $('#monitoring-panel');
		treatmentPanel = $('#treatment-panel');
		diagnosisPanel = $('#diagnosis-panel');
		exclusionPanel = $('#exclusion-panel');
		patientsPanelTemplate = $('#patients-panel');
		breakdownPanel = $('#breakdown-panel');
		actionPlanPanel = $('#action-plan-panel');
		patientList = $('#patient-list');
		patientListSimple = $('#patient-list-simple');
		suggestedPlanTemplate = $('#suggested-plan-template');
		breakdownTableTemplate = $('#breakdown-table-template');
		individualPanel = $('#individual-panel');
		valueTrendPanel = $('#value-trend-panel');
    medicationPanel = $('#medications-panel');
		actionPlanList = $('#action-plan-list');

		//Selectors
		bottomLeftPanel = $('#bottom-left-panel');
		bottomRightPanel = $('#bottom-right-panel');
		topPanel = $('#top-panel');
		topLeftPanel = $('#top-left-panel');
		topRightPanel = $('#top-right-panel');
    midPanel = $('#mid-panel');
		farLeftPanel = $('#left-panel');
		farRightPanel = $('#right-panel');
  };

	var wireUpPages = function () {
		$('#pick-nice').on('click', function(e){
      //load data
      var currentColour = $('body').css('backgroundColor');
      $('body').animate({ backgroundColor: "rgba(255,255,0,0.7)" },100).animate({backgroundColor : currentColour},500);
      //flash background
      //$('body').removeClass('qof');
      //e.stopPropagation();
		});

		$('#pick-qof').on('click', function(e){
    var currentColour = $('body').css('backgroundColor');
    $('body').animate({ backgroundColor: "rgba(255,255,0,0.7)" },100).animate({backgroundColor : currentColour},800);
      //$('body').addClass('qof');
      //e.stopPropagation();
		});

    wireUpTooltips();

		/**********************************
		 ** Patient search auto complete **
		 **********************************/
    wireUpSearchBox();

    $('#data-file').on('change', function(evt){
      $('#data-file-wrapper').addClass('disabled').text("Loading...");
      var file = evt.target.files[0]; // FileList object
      var reader = new FileReader();

      reader.onload = (function() {
        return function(e) {
          var JsonObj = JSON.parse(e.target.result);
          getData(null, JsonObj);
          console.log(JsonObj);

          wireUpSearchBox();

          setTimeout(function() { $('#data-file-wrapper').hide(500); }, 1000);
        };
      })(file);

      reader.readAsText(file);
    });

    $('#patient-file').on('change', function(evt){
      $('#patient-file-wrapper').addClass('disabled').text("Loading...");
      var file = evt.target.files[0]; // FileList object
      var reader = new FileReader();

      reader.onload = (function() {
        return function(e) {
          var lines = e.target.result.split("\n");
          local.patLookup = {};
          for(var i = 0; i < lines.length; i++){
            var fields = lines[i].split(",");
            if(fields.length!==2) continue;
            local.patLookup[fields[0].trim()] = fields[1].trim();
          }

          wireUpSearchBox();

          setTimeout(function() { $('#patient-file-wrapper').hide(500); }, 1000);
        };
      })(file);

      reader.readAsText(file);
    });

    //exportPlan
    $('.download-outstanding').on('click', function(){
      exportPlan('outstanding');
    });
    $('.download-completed').on('click', function(){
      exportPlan('completed');
    });
    $('.download-all').on('click', function(){
      exportPlan('all');
    });

    $('#outstandingTasks').on('click', function(e){
      e.preventDefault();

      $('#welcome-tabs li').removeClass('active');
      $(this).closest('li').addClass('active');
      var template = $('#welcome-task-list').html();
      var rendered = Mustache.render(template);
      $('#welcome-tab-content').fadeOut(100, function(){
        $(this).html(rendered);
        populateWelcomeTasks();
        $(this).fadeIn(100);
      });
    });

    $('#completedTasks').on('click', function(e){
      e.preventDefault();

      $('#welcome-tabs li').removeClass('active');
      $(this).closest('li').addClass('active');
      var template = $('#welcome-task-list').html();
      var rendered = Mustache.render(template);
      $('#welcome-tab-content').fadeOut(100, function(){
        $(this).html(rendered);
        populateWelcomeTasks(true);
        $(this).fadeIn(100);
      });
    });

    if(bb.hash !== location.hash) location.hash = bb.hash;
    loadContent(location.hash, true);
	};

  var loadActionPlan = function(callback) {
    var r = Math.random();
    $.getJSON("action-plan.json?v="+r, function(file){
      local.actionPlan = file.diseases;
      local.actionText = file.plans;
      callback();
    });
  };

  var loadData = function(file){
    var d="", j, k, data = file.diseases;

    local.data = jQuery.extend({}, data); //copy

    local.data.patients = file.patients;
    local.data.patientArray = [];
    for(var o in file.patients) {
      if(file.patients.hasOwnProperty(o)) {
        local.data.patientArray.push(o);
      }
    }

    for(d in data){
      local.pathwayNames[d] = data[d]["display-name"];
      local.diseases.push({"id":d,"link": data[d].link ? data[d].link : "main/"+d, "faIcon":data[d].icon, "name":data[d]["display-name"]});
      local.data[d].suggestions = local.actionPlan[d].team;
      $.extend(local.data[d].monitoring, {"breakdown":[], "bdown":{}});
      $.extend(local.data[d].treatment, {"breakdown":[], "bdown":{}});
      $.extend(local.data[d].diagnosis, {"breakdown":[], "bdown":{}});
      $.extend(local.data[d].exclusions, {"breakdown":[], "bdown":{}});

      if(!local.data[d].monitoring.header) continue;
      for(j=0; j < local.data[d].monitoring.items.length; j++) {
        local.data[d].monitoring.breakdown.push([local.data[d].monitoring.items[j].name, local.data[d].monitoring.items[j].n]);
        local.data[d].monitoring.bdown[local.data[d].monitoring.items[j].name] = local.data[d].monitoring.items[j];
        local.data[d].monitoring.bdown[local.data[d].monitoring.items[j].name].suggestions = local.actionPlan[d].monitoring.individual[local.data[d].monitoring.items[j].name];
        for(k=0; k < local.data[d].monitoring.items[j].patients.length; k++) {
          if(!local.data.patients[local.data[d].monitoring.items[j].patients[k]].breach) local.data.patients[local.data[d].monitoring.items[j].patients[k]].breach = [];
          local.data.patients[local.data[d].monitoring.items[j].patients[k]].breach.push({"pathwayId":d, "pathwayStage":"monitoring", "subsection":local.data[d].monitoring.items[j].name});
        }
      }
      for(j=0; j < local.data[d].treatment.items.length; j++) {
        local.data[d].treatment.breakdown.push([local.data[d].treatment.items[j].name, local.data[d].treatment.items[j].n]);
        local.data[d].treatment.bdown[local.data[d].treatment.items[j].name] = local.data[d].treatment.items[j];
        local.data[d].treatment.bdown[local.data[d].treatment.items[j].name].suggestions = local.actionPlan[d].treatment.individual[local.data[d].treatment.items[j].name];
        for(k=0; k < local.data[d].treatment.items[j].patients.length; k++) {
          if(!local.data.patients[local.data[d].treatment.items[j].patients[k]].breach) local.data.patients[local.data[d].treatment.items[j].patients[k]].breach = [];
          local.data.patients[local.data[d].treatment.items[j].patients[k]].breach.push({"pathwayId":d, "pathwayStage":"treatment", "subsection":local.data[d].treatment.items[j].name});
        }
      }
      for(j=0; j < local.data[d].exclusions.items.length; j++) {
        local.data[d].exclusions.breakdown.push([local.data[d].exclusions.items[j].name, local.data[d].exclusions.items[j].n]);
        local.data[d].exclusions.bdown[local.data[d].exclusions.items[j].name] = local.data[d].exclusions.items[j];
        local.data[d].exclusions.bdown[local.data[d].exclusions.items[j].name].suggestions = local.actionPlan[d].exclusions.individual[local.data[d].exclusions.items[j].name];
        for(k=0; k < local.data[d].exclusions.items[j].patients.length; k++) {
          if(!local.data.patients[local.data[d].exclusions.items[j].patients[k]].breach) local.data.patients[local.data[d].exclusions.items[j].patients[k]].breach = [];
          local.data.patients[local.data[d].exclusions.items[j].patients[k]].breach.push({"pathwayId":d, "pathwayStage":"exclusions", "subsection":local.data[d].exclusions.items[j].name});
        }
      }
      for(j=0; j < local.data[d].diagnosis.items.length; j++) {
        local.data[d].diagnosis.breakdown.push([local.data[d].diagnosis.items[j].name, local.data[d].diagnosis.items[j].n]);
        local.data[d].diagnosis.bdown[local.data[d].diagnosis.items[j].name] = local.data[d].diagnosis.items[j];
        local.data[d].diagnosis.bdown[local.data[d].diagnosis.items[j].name].suggestions = local.actionPlan[d].diagnosis.individual[local.data[d].diagnosis.items[j].name];
        for(k=0; k < local.data[d].diagnosis.items[j].patients.length; k++) {
          if(!local.data.patients[local.data[d].diagnosis.items[j].patients[k]].breach) local.data.patients[local.data[d].diagnosis.items[j].patients[k]].breach = [];
          local.data.patients[local.data[d].diagnosis.items[j].patients[k]].breach.push({"pathwayId":d, "pathwayStage":"diagnosis", "subsection":local.data[d].diagnosis.items[j].name});
        }
      }
    }
  };

	var getData = function(callback, json) {
    if(json) {
      loadData(json);
      if(typeof callback === 'function') callback();
    } else {
      var r = Math.random();
  		$.getJSON("data.json?v="+r, function(file) {
  			loadData(file);
        if(typeof callback === 'function') callback();
  		}).fail(function(err){
        alert("data.json failed to load!! - if you've changed it recently check it's valid json at jsonlint.com");
      });
    }
	};

	var initialize = function(){
    preWireUpPages();

    loadActionPlan(function(){
      getData(wireUpPages);
    });
	};

	window.bb = {
    "version" : "1.25",
		"init" : initialize,
    "_local":local
	};
})();

/********************************************************
*** Shows the pre-load image and slowly fades it out. ***
********************************************************/
$(window).load(function() {
  $('.loading-container').fadeOut(1000, function() {
	$(this).remove();
  });
});

/******************************************
*** This happens when the page is ready ***
******************************************/
$(document).on('ready', function () {
  //Grab the hash if exists - IE seems to forget it
  bb.hash = location.hash;
	//Load the data then wire up the events on the page
	bb.init();

	//Sorts out the data held locally in the user's browser
	if(!localStorage.bb) localStorage.bb = JSON.stringify({});
	var obj = JSON.parse(localStorage.bb);
  if(!obj.version || obj.version!==bb.version){
    localStorage.bb = JSON.stringify({"version" : bb.version});
  }

	$('[data-toggle="tooltip"]').tooltip({container: 'body', delay: { "show": 1000, "hide": 100 }});
  $('[data-toggle="lone-tooltip"]').tooltip({container: 'body', delay: { "show": 700, "hide": 100 }});
  $('[data-toggle="lone-tooltip"]').on('shown.bs.tooltip',function(e){
    $('[data-toggle="tooltip"]').not(this).tooltip('hide');
  });

  //ensure on first load the login screen is cached to the history
  history.pushState(null, null, '');
});
