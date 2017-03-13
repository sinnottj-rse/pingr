var base = require('../base.js'),
  data = require('../data.js'),
  log = require('../log.js'),
  actionPlan = require('./actionPlan.js');

var patientActions = [];

var iap = {

  create: function(nhs, pathwayId, pathwayStage, standard) {
    var dataObj = { nhs: nhs };
    if (data.text.pathways[pathwayId] && data.text.pathways[pathwayId][pathwayStage] && data.text.pathways[pathwayId][pathwayStage].standards[standard]) {
      dataObj.indicator = data.text.pathways[pathwayId][pathwayStage].standards[standard].tabText;
    } else {
      dataObj.indicator = null;
    }
    return require("templates/individual-action-plan")(dataObj);
  },

  show: function(panel, pathwayId, pathwayStage, standard, patientId) {
    panel.html(iap.create(data.patLookup ? data.patLookup[patientId] : patientId, pathwayId, pathwayStage, standard));
    iap.wireUp(pathwayId, pathwayStage, standard, patientId);

    /*panel.find('div.fit-to-screen-height').niceScroll({
      cursoropacitymin: 0.3,
      cursorwidth: "7px",
      horizrailenabled: false
    });*/
  },

  updateAction: function(action) {
    //Use actionTextId to find the right row
    //var yesbox = individualTab.find('tr[data-id="' + action.actionTextId + '"] label.btn-yes input');
    //var nobox = individualTab.find('tr[data-id="' + action.actionTextId + '"] label.btn-no input');
    var yesbox = individualTab.find('li[data-id="' + action.actionTextId + '"] label.btn-yes input');
    var nobox = individualTab.find('li[data-id="' + action.actionTextId + '"] label.btn-no input');
    //checked action inactive
    if (action.agree === true) {
      yesbox.each(function() { this.checked = true; });
      yesbox.parent().removeClass("inactive").addClass("active");
      nobox.each(function() { this.checked = false; });
      nobox.parent().removeClass("active").addClass("inactive");
    } else if (action.agree === false) {
      nobox.each(function() { this.checked = true; });
      nobox.parent().removeClass("inactive").addClass("active");
      yesbox.each(function() { this.checked = false; });
      yesbox.parent().removeClass("active").addClass("inactive");
    } else {
      yesbox.each(function() { this.checked = false; });
      yesbox.parent().removeClass("active inactive");
      nobox.each(function() { this.checked = false; });
      nobox.parent().removeClass("active inactive");
    }

    //yesbox.closest('tr').data('agree', action.agree);
    yesbox.closest('li').data('agree', action.agree);

    iap.updateIndividualSapRows();
  },

  wireUp: function(pathwayId, pathwayStage, standard, patientId) {
    individualTab = $('#tab-plan-individual');

    //find [] and replace with copy button

    /*$('#advice-list').on('click', '.cr-styled input[type=checkbox]', function() {
      var ACTIONID = $(this).closest('tr').data('id');
      log.editAction(data.patientId, ACTIONID, null, this.checked);

      if (this.checked) {
        log.recordEvent(pathwayId, data.patientId, "Item completed");
        var self = this;
        $(self).parent().attr("title", "").attr("data-original-title", "").tooltip('fixTitle').tooltip('hide');
        setTimeout(function(e) {
          $(self).parent().fadeOut(300, function() {
            var parent = $(this).parent();
            $(this).replaceWith(base.createPanel($('#checkbox-template'), {
              "done": true
            }));
            base.wireUpTooltips();
            parent.find('button').on('click', function() {
              ACTIONID = $(this).closest('tr').data('id');
              log.editAction(data.patientId, ACTIONID, null, false);
              $(this).replaceWith(base.createPanel($('#checkbox-template'), {
                "done": false
              }));
              iap.updateIndividualSapRows();
            });
          });
        }, 1000);
      }

      iap.updateIndividualSapRows();
    });*/

    /*$('#personalPlanIndividual').on('click', 'input[type=checkbox]', function() {
      var PLANID = $(this).closest('tr').data("id");
      log.editPlan(PLANID, null, this.checked);

      if (this.checked) {
        $(this).parent().parent().parent().addClass('success');
        log.recordEvent(pathwayId, data.patientId, "Personal plan item");
        var self = this;
        $(self).parent().attr("title", "").attr("data-original-title", "").tooltip('fixTitle').tooltip('hide');
        setTimeout(function(e) {
          $(self).parent().fadeOut(300, function() {
            var parent = $(this).parent();
            $(this).replaceWith(base.createPanel($('#checkbox-template'), {
              "done": true
            }));
            base.wireUpTooltips();
            parent.find('button').on('click', function() {
              PLANID = $(this).closest('tr').data('id');
              log.editPlan(data.patientId, PLANID, null, false);
              $(this).replaceWith(base.createPanel($('#checkbox-template'), {
                "done": false
              }));
              iap.updateIndividualSapRows();
            });
          });
        }, 1000);
      }
    }).on('click', '.btn-undo', function(e) {
      var PLANID = $(this).closest('tr').data('id');
      log.editPlan(PLANID, null, false);
      $(this).replaceWith(base.createPanel($('#checkbox-template'), {
        "done": false
      }));
      iap.updateIndividualSapRows();
      e.stopPropagation();
    });*/
    individualTab.on('click', '.edit-plan', function() {
      var action = userDefinedPatientActionsObject[$(this).closest('tr').data("id")];

      $('#editActionPlanItem').val(action.actionText);

      $('#editPlan').off('hidden.bs.modal').on('hidden.bs.modal', function() {
        iap.displayPersonalisedIndividualActionPlan($('#personalPlanIndividual'));
      }).off('shown.bs.modal').on('shown.bs.modal', function() {
        $('#editActionPlanItem').focus();
      }).off('click', '.save-plan').on('click', '.save-plan', function() {
        var oldActionId = action.actionTextId;
        action.actionText = $('#editActionPlanItem').val();
        action.actionTextId = action.actionText.toLowerCase().replace(/[^a-z0-9]/g, "");
        if (action.actionTextId !== oldActionId) {
          log.updateUserDefinedPatientAction(patientId, oldActionId, action);
          delete userDefinedPatientActionsObject[oldActionId];
          if (!userDefinedPatientActionsObject[action.actionTextId]) userDefinedPatientActionsObject[action.actionTextId] = action;
          iap.updateAction(action);
        }
        $('#editPlan').modal('hide');
      }).off('keyup', '#editActionPlanItem').on('keyup', '#editActionPlanItem', function(e) {
        if (e.which === 13) $('#editPlan .save-plan').click();
      }).modal();
    }).on('click', '.delete-plan', function() {
      var action = userDefinedPatientActionsObject[$(this).closest('tr').data("id")];

      $('#modal-delete-item').html(action.actionText);

      $('#deletePlan').off('hidden.bs.modal').on('hidden.bs.modal', function() {
        iap.displayPersonalisedIndividualActionPlan($('#personalPlanIndividual'));
      }).off('click', '.delete-plan').on('click', '.delete-plan', function() {
        log.deleteUserDefinedPatientAction(patientId, action.actionTextId);
        delete userDefinedPatientActionsObject[action.actionTextId];

        $('#deletePlan').modal('hide');
      }).modal();
    }).on('click', '.add-plan', function() {
      //var actionText = $(this).parent().parent().find('textarea').val();
      var actionText = $('textarea.form-control').val();
      var actionTextId = actionText.toLowerCase().replace(/[^a-z0-9]/g,"");
      log.recordIndividualPlan(actionText, patientId, function(err, a){
        if(!userDefinedPatientActionsObject[actionTextId]) userDefinedPatientActionsObject[actionTextId]=a;
        iap.displayPersonalisedIndividualActionPlan($('#personalPlanIndividual'));
      });
    }).on('change', '.btn-toggle input[type=checkbox]', function() {
      /*iap.updateIndividualSapRows();*/
    }).on('click', '.btn-undo', function(e) {
      /*var ACTIONID = $(this).closest('tr').data('id');
      log.editAction(data.patientId, ACTIONID, null, false);
      $(this).replaceWith(base.createPanel($('#checkbox-template'), {
        "done": false
      }));
      iap.updateIndividualSapRows();*/
    }).on('click', '.btn-yes', function(e) {
      // var AGREE_STATUS = $(this).closest('tr').data('agree');
      // var action = patientActionsObject[$(this).closest('tr').data('id')];
      var AGREE_STATUS = $(this).closest('li').data('agree');
      var action = patientActionsObject[$(this).closest('li').data('id')];

      if (AGREE_STATUS === false) {
        //do nothing - shouldn't be able to get here
        console.log("nothing doing");
      } else {
        action.agree = AGREE_STATUS ? null : true;
        if (action.agree) action.history.unshift($('#user_fullname').text().trim() + " agreed with this on " + (new Date()).toDateString());
        log.updateIndivdualAction(patientId, action);
        iap.updateAction(action);
      }

      e.stopPropagation();
      e.preventDefault();
    }).on('click', '.btn-no', function(e) {
      //var AGREE_STATUS = $(this).closest('tr').data('agree');
      //var action = patientActionsObject[$(this).closest('tr').data('id')];

      var AGREE_STATUS = $(this).closest('li').data('agree');
      var action = patientActionsObject[$(this).closest('li').data('id')];

      if (AGREE_STATUS === true) {
        //do nothing - shouldn't be able to get here
        console.log("nothing doing");
        e.stopPropagation();
        e.preventDefault();
      } else if (AGREE_STATUS === false) {
        //editing reason
        iap.launchModal(data.selected, action.actionText, action.rejectedReason, action.rejectedReasonText, true, function() {
          var reasonText = actionPlan.rejectedReason === "" && actionPlan.rejectedReasonText === "" ? " - no reason given" : ". You disagreed because you said: '" + (actionPlan.rejectedReason || "") + "; " + actionPlan.rejectedReasonText + ".'";
          action.history.unshift($('#user_fullname').text().trim() + " disagreed with this on " + (new Date()).toDateString() + reasonText);
          action.agree = false;
          action.rejectedReason = actionPlan.rejectedReason;
          action.rejectedReasonText = actionPlan.rejectedReasonText;
          log.updateIndivdualAction(patientId, action);
          iap.updateAction(action);
        }, null, function() {
          action.agree = null;
          delete action.rejectedReason;
          delete action.rejectedReasonText;
          log.updateIndivdualAction(patientId, action);
          iap.updateAction(action);
        });
        e.stopPropagation();
        e.preventDefault();
      } else {
        //disagreeing
        iap.launchModal(data.selected, action.actionText, action.rejectedReason, action.rejectedReasonText, false, function() {
          var reasonText = actionPlan.rejectedReason === "" && actionPlan.rejectedReasonText === "" ? " - no reason given" : ". You disagreed because you said: '" + (actionPlan.rejectedReason || "") + "; " + actionPlan.rejectedReasonText + ".'";
          action.history.unshift($('#user_fullname').text().trim() + " disagreed with this on " + (new Date()).toDateString() + reasonText);
          action.agree = false;
          action.rejectedReason = actionPlan.rejectedReason;
          action.rejectedReasonText = actionPlan.rejectedReasonText;
          log.updateIndivdualAction(patientId, action);
          iap.updateAction(action);
        });
        e.stopPropagation();
        e.preventDefault();
      }
    }).on('keyup', 'input[type=text]', function(e) {
      if (e.which === 13) {
        individualTab.find('.add-plan').click();
      }
    });

    $('#advice-list').off('click', '.show-more-than-3');
    $('#advice-list').on('click', '.show-more-than-3', function(e) {
      iap.populateIndividualSuggestedActions(patientId, pathwayId, pathwayStage, standard, true);
    });

    $('#advice-list').off('click', '.show-less-than-3');
    $('#advice-list').on('click', '.show-less-than-3', function(e) {
      iap.populateIndividualSuggestedActions(patientId, pathwayId, pathwayStage, standard, false);
    });

    $('#advice-list').off('click', '.show-more');
    $('#advice-list').on('click', '.show-more', function(e) {
      var id = $(this).data("id");
      var elem = $('.show-more-row[data-id="' + id + '"]');
      if (elem.is(':visible')) {
        $('.show-more[data-id="' + id + '"]:first').show();
        elem.hide();
      } else {
        $(this).hide();
        elem.show('fast');
      }
      // do not give a default action
      e.preventDefault();
      e.stopPropagation();
      return false;
    });
    //*B* ??edit this to handle the show more or less actions
    $('#advice-list').off('click', 'tr.show-more-row a:not(.show-more)');
    $('#advice-list').on('click', 'tr.show-more-row a:not(.show-more)', function(e) {
      log.event("nice-link-clicked", window.location.hash, [{ key: "link", value: e.currentTarget.href }]);
      e.stopPropagation();
    });

    iap.loadAndPopulateIndividualSuggestedActions(patientId, pathwayId, pathwayStage, standard, false);
  },

  updateIndividualSapRows: function() {
    //FUNCTION OBJECTIVE
    //indicate the confirmation, indifference or declination of the user towards this action
    //
    //user agrees - agree button highlights, disagree button lowlight
    //user indifferent - both buttons visible but faded
    //user disagree - agree button highlights, disagree button lowlight

    $('#advice-list').add('#personalPlanIndividual').find('li.suggestion').each(function() {
      var self = $(this);
      var id = self.data("id");
      var all = $('.show-more-row[data-id="' + id + '"],.suggestion[data-id="' + id + '"]'); //get every suggestion
      var any = false; // dont know what this does
      //if any button is selected...
      self.find('.btn-toggle input[type=checkbox]:checked').each(function() {
        //set the tool tip
        any = true;
        //if there is a history - display appropriate title
        if (patientActionsObject[self.data("id")].history != "") {
          var tooltipInfo = "<p>" + patientActionsObject[self.data("id")].history[0].replace($('#user_fullname').text().trim(), "You") + "</p><p>Click again to cancel</p>";
          $(this).closest('label').attr("title", tooltipInfo).attr("data-original-title", tooltipInfo).attr("data-html", "true").tooltip('fixTitle').tooltip('hide');
        }
        //if no history but selected is affirmative
        else if (this.value === "yes") {
          $(this).closest('label').attr("title", "You agreed with this - click again to cancel").tooltip('fixTitle').tooltip('hide');
        }
        //if no history but selected is negative
        else {
          $(this).closest('label').attr("title", "You disagreed with this - click again to edit/cancel").tooltip('fixTitle').tooltip('hide');
        }
      });
      //if only one button is selected
      if (self.find('.btn-toggle input[type=checkbox]:not(:checked)').length == 1) {
        //demote the non-selected button
        self.find('.btn-toggle input[type=checkbox]:not(:checked)').parent().addClass("inactive btn-simple indifferent-select").attr("title", "").attr("data-original-title", "").attr("data-html", "true").tooltip('fixTitle').tooltip('hide');
        //promote the selected button
        self.find('.btn-toggle input[type=checkbox]:checked').parent().removeClass("btn-simple indifferent-select");
      }
      else {
        //if both buttons are not selected make sure they are set to appropriate presentation
        self.find('.btn-toggle input[type=checkbox]:not(:checked)').parent().removeClass("btn-simple inactive").addClass("indifferent-select");
      }

      if (!any) {
        //all.removeClass('danger');
        //all.removeClass('active');
        //all.removeClass('success');

        self.find('.btn-toggle.btn-yes').attr("title", "Click to agree with this action and save it in your agreed actions list").attr("data-html", "true").tooltip('fixTitle').tooltip('hide');
        self.find('.btn-toggle.btn-no').attr("title", "Click to disagree with this action and remove it from your suggested actions list").attr("data-html", "true").tooltip('fixTitle').tooltip('hide');
      }

      //base.wireUpTooltips();
    });
    base.wireUpTooltips();
  },

  displayPersonalisedIndividualActionPlan: function(parentElem) {
    var tmpl = require('templates/action-plan-list');
    var userDefinedActions = Object.keys(userDefinedPatientActionsObject).map(function(v){return userDefinedPatientActionsObject[v];});
    parentElem.html(tmpl({
      "hasSuggestions": userDefinedActions && userDefinedActions.length > 0,
      "suggestions": userDefinedActions
    }));

    iap.updateIndividualSapRows();
  },

  loadAndPopulateIndividualSuggestedActions: function(patientId, pathwayId, pathwayStage, standard, visible) {
    data.getPatientActionData(patientId, function(err, a) {
      patientActionsObject = {};
      userDefinedPatientActionsObject = {};
      a.userDefinedActions.forEach(function(v){
        userDefinedPatientActionsObject[v.actionTextId] = v;
      });
      patientActions = a.actions.map(function(v) {
        v.indicatorListText = v.indicatorList.map(function(vv) {
          return { id: vv, text: data.text.pathways[vv.split(".")[0]][vv.split(".")[1]].standards[vv.split(".")[2]].tabText };
        });
        if (v.agree !== true && v.agree !== false) v.agree = null;
        patientActionsObject[v.actionTextId] = v;
        return v;
      });
      iap.populateIndividualSuggestedActions(patientId, pathwayId, pathwayStage, standard, visible);
    });
  },

  populateIndividualSuggestedActions: function(patientId, pathwayId, pathwayStage, standard, visible) {
    var localData = {
      "nhsNumber": data.patLookup ? data.patLookup[patientId] : patientId,
      "patientId": patientId,
      visible: visible
    };

    if (patientActions.length === 0 || (pathwayId && pathwayStage && standard && patientActions.filter(function(v) {
        return v.indicatorList.indexOf([pathwayId, pathwayStage, standard].join(".")) > -1;
      }).length === 0)) {
      localData.noSuggestions = true;
    } else {

      localData.suggestions = patientActions;

      localData.suggestions = localData.suggestions.filter(function(v) {
        if (!pathwayId || !pathwayStage || !standard) return true;
        return v.indicatorList.indexOf([pathwayId, pathwayStage, standard].join(".")) > -1;
      });
    }
    /*if (patientActions.length === 0 || (pathwayId && pathwayStage && standard && patientActions.filter(function(v) {
        return v.indicatorId === [pathwayId, pathwayStage, standard].join(".");
      }).length === 0)) {
      localData.noSuggestions = true;
    } else {

      localData.suggestions = base.dedupeAndSortActions(base.mergeIndividualStuff(patientActions, patientId));

      localData.suggestions = localData.suggestions.filter(function(v) {
        if (!pathwayId || !pathwayStage || !standard) return true;
        return v.indicatorList.indexOf([pathwayId, pathwayStage, standard].join(".")) > -1;
      }).map(function(v) {
        v.indicatorList = v.indicatorList.map(function(vv) {
          return { id: vv, text: data.text.pathways[vv.split(".")[0]][vv.split(".")[1]].standards[vv.split(".")[2]].tabText };
        });
        v.id = v.actionText.replace(/[^A-Za-z0-9]/g, "");
        return v;
      });
    }*/

    $('#advice-placeholder').hide();
    $('#advice').show();

    //base.createPanelShow(individualPanel, $('#advice-list'), localData);
    var tmpl = require("templates/individual");
    $('#advice-list').html(tmpl(localData));

    //Wire up any clipboard stuff in the suggestions
    var isVision = $('#practice_system').text() === "Vision";
    $('#advice-list').find('span:contains("[COPY")').each(function() {
      var html = $(this).html();
      $(this).html(html.replace(/\[COPY:([^\]\.]*)(\.*)\]/g, (isVision ? '#$1$2' : '$1') + ' <button type="button" data-clipboard-text="' + (isVision ? '#$1$2' : '$1') + '" data-content="Copied!<br><strong>Use Ctrl + v to paste into ' + $('#practice_system').text() + '!</strong>" data-toggle="tooltip" data-placement="top" title="Copy ' + (isVision ? '#$1$2' : '$1') + ' to clipboard." class="btn btn-xs btn-default btn-copy"><span class="fa fa-clipboard"></span></button>'));
    });
    $('#advice-list').find('td:contains("[")').each(function() {
      var html = $(this).html();
      $(this).html(html.replace(/\[([^\]\.]*)(\.*)\]/g, ' <button type="button" data-clipboard-text="' + (isVision ? '#$1$2' : '$1') + '" data-content="Copied!<br><strong>Use Ctrl + v to paste into ' + $('#practice_system').text() + '!</strong>" data-toggle="tooltip" data-placement="top" title="Copy ' + (isVision ? '#$1$2' : '$1') + ' to clipboard." class="btn btn-xs btn-default btn-copy"><span class="fa fa-clipboard"></span></button>'));
    });
    $('#advice-list').find('li:contains("[")').each(function() {
      var html = $(this).html();
      $(this).html(html.replace(/\[([^\]\.]*)(\.*)\]/g, ' <button type="button" data-clipboard-text="' + (isVision ? '#$1$2' : '$1') + '" data-content="Copied!<br><strong>Use Ctrl + v to paste into ' + $('#practice_system').text() + '!</strong>" data-toggle="tooltip" data-placement="top" title="Copy ' + (isVision ? '#$1$2' : '$1') + ' to clipboard." class="btn btn-xs btn-round btn-default btn-copy"><span class="material-icons">content_copy</span></button>'));
    });

    $('#advice-list').find('span:contains("[INFO")').each(function() {
      var html = $(this).html();
      var subsection = $(this).data().subsection;
      var desc = data[pathwayId][pathwayStage].standards[standard].opportunities.filter(function(val) {
          return val.name === subsection;
        }).length > 0 ?
        data[pathwayId][pathwayStage].standards[standard].opportunities.filter(function(val) {
          return val.name === subsection;
        })[0].desc : subsection;
      var tooltip = subsection ? "This action is suggested because PINGR classified this patient as:'" + desc + "'" : '';
      var newHtml = ' <i class="fa fa-info-circle fa-lg info-button clickable" data-toggle="tooltip" data-placement="right" title="' + tooltip + '"></i>';
      $(this).html(html.replace(/\[INFO\]/g, newHtml));
    });
    //*b* I presume this can go?? - same as in team action
    $('#advice-list').find('span:contains("[MED-SUGGESTION")').each(function() {
      var html = $(this).html();
      var suggestion = Math.random() < 0.33 ? "Increase Ramipril to 10mg per day" : (Math.random() < 0.5 ? "Consider adding an ACE inhibior" : "Consider adding a thiazide-like diuretic");
      $(this).html(html.replace(/\[MED\-SUGGESTION\]/g, suggestion));
    });

    $('#advice-list').find('td:contains("Reasoning")').each(function() {
      var contents = $(this).contents();
      var i = 0;
      while ($(contents[i]).text() !== "Reasoning" && i < contents.length) {
        i++;
      }
      if (i < contents.length - 1) {
        var reasoning = $(contents[i]);
        var content = "Reasoning\r\n" + $(contents[i + 1]).html()
          .replace(/ +/g, " ")
          .replace(/<li>/g, "  - ")
          .replace(/<\/li>/g, "\r\n")
          .replace(/<\/?strong>/g, "")
          .replace(/&gte;/g, "≥")
          .replace(/&lte;/g, "≤")
          .replace(/&gt;/g, ">")
          .replace(/&lt;/g, "<")
          .replace(/<a.+href=["']([^"']+)["'].*>([^<]+)<\/a>/g, "$2 - $1");
        reasoning.replaceWith('Reasoning <button type="button" data-clipboard-text="' + content + '" data-content="Copied!<br><strong>Use Ctrl + v to paste into ' + $('#practice_system').text() + '!</strong>" data-toggle="tooltip" data-placement="top" title="Copy reasoning to clipboard." class="btn btn-xs btn-default btn-copy"><span class="material-icons">content_copy</span></button>');
      }
    });

    base.setupClipboard($('.btn-copy'), true);

    iap.displayPersonalisedIndividualActionPlan($('#personalPlanIndividual'));
  },

  launchModal: function(label, value, rejectedReason, rejectedReasonText, isUndo, callbackOnSave, callbackOnCancel, callbackOnUndo) {
    var reasons = [{
      "reason": "Already done this",
      "value": "done"
    }, {
      "reason": "Wouldn't work",
      "value": "nowork"
    }, {
      "reason": "Something else",
      "value": "else"
    }];
    if (rejectedReason) {
      for (var i = 0; i < reasons.length; i++) {
        if (reasons[i].reason === rejectedReason) {
          reasons[i].checked = true;
          break;
        }
      }
    }
    actionPlan.launchModal({
      "header": "Disagree with a suggested action",
      "isUndo": isUndo,
      "item": value,
      "placeholder": "Provide more information here...",
      "reasons": reasons
    }, label, value, rejectedReasonText || null, callbackOnSave, callbackOnCancel, callbackOnUndo);
  }

};

module.exports = iap;
