var base = require('../base.js'),
  data = require('../data.js'),
  log = require('../log.js'),
  actionPlan = require('./actionPlan.js');

var teamActions = [];

var tap = {

  create: function(title) {
    return require("templates/team-action-plan")({ title: title });
  },

  show: function(panel, title, pathwayId, pathwayStage, standard) {
    panel.html(tap.create(title));
    tap.wireUp(pathwayId, pathwayStage, standard);
  },

  updateAction: function(action) {
    //Use actionTextId to find the right row
    var yesbox = actionPanel.find('tr[data-id="' + action.actionTextId + '"] label.btn-yes input');
    var nobox = actionPanel.find('tr[data-id="' + action.actionTextId + '"] label.btn-no input');
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

    yesbox.closest('tr').data('agree', action.agree);

    tap.updateTeamSapRows();
  },

  wireUp: function(pathwayId, pathwayStage, standard) {
    actionPanel = $('#team-action-panel');
    userActionPanel = $('#user-action-panel');

    var indicatorId = "";
    if (pathwayId && pathwayStage && standard) indicatorId = [pathwayId, pathwayStage, standard].join(".");

    userActionPanel.on('click', '.edit-plan', function() {
      var action = userDefinedTeamActionsObject[$(this).closest('tr').data("id")];

      $('#editActionPlanItem').val(action.actionText);

      $('#editPlan').off('hidden.bs.modal').on('hidden.bs.modal', function() {
        tap.displayPersonalisedTeamActionPlan($('#personalPlanTeam'));
      }).off('shown.bs.modal').on('shown.bs.modal', function() {
        $('#editActionPlanItem').focus();
      }).off('click', '.save-plan').on('click', '.save-plan', function() {
        var oldActionId = action.actionTextId;
        action.actionText = $('#editActionPlanItem').val();
        action.actionTextId = action.actionText.toLowerCase().replace(/[^a-z0-9]/g, "");
        if (action.actionTextId !== oldActionId) {
          log.updateUserDefinedTeamAction(oldActionId, action);
          delete userDefinedTeamActionsObject[oldActionId];
          if (!userDefinedTeamActionsObject[action.actionTextId]) userDefinedTeamActionsObject[action.actionTextId] = action;
          tap.updateAction(action);
        }
        $('#editPlan').modal('hide');
      }).off('keyup', '#editActionPlanItem').on('keyup', '#editActionPlanItem', function(e) {
        if (e.which === 13) $('#editPlan .save-plan').click();
      }).modal();
    }).on('click', '.delete-plan', function() {
      var action = userDefinedTeamActionsObject[$(this).closest('tr').data("id")];

      $('#modal-delete-item').html(action.actionText);

      $('#deletePlan').off('hidden.bs.modal').on('hidden.bs.modal', function() {
        tap.displayPersonalisedTeamActionPlan($('#personalPlanTeam'));
      }).off('click', '.delete-plan').on('click', '.delete-plan', function() {
        log.deleteUserDefinedTeamAction(action.actionTextId);
        delete userDefinedTeamActionsObject[action.actionTextId];

        $('#deletePlan').modal('hide');
      }).modal();
    }).on('click', '.add-plan', function() {
      var actionText = $(this).parent().parent().find('textarea').val();
      $(this).parent().parent().find('textarea').val("");
      var actionTextId = actionText.toLowerCase().replace(/[^a-z0-9]/g, "");
      log.recordTeamPlan(actionText, indicatorId, function(err, a) {
        if (!userDefinedTeamActionsObject[actionTextId]) userDefinedTeamActionsObject[actionTextId] = a;
        tap.displayPersonalisedTeamActionPlan($('#personalPlanTeam'));
      });
    }).on('keyup', 'input[type=text]', function(e) {
      if (e.which === 13) {
        actionPanel.find('.add-plan').click();
      }
    });

    actionPanel.on('change', '.btn-toggle input[type=checkbox]', function() {
      //tap.updateTeamSapRows();
    }).on('click', '.btn-undo', function(e) {

    }).on('click', '.btn-yes', function(e) {
      var AGREE_STATUS = $(this).closest('tr').data('agree');
      var action = teamActionsObject[$(this).closest('tr').data('id')];

      action.agree = AGREE_STATUS ? null : true;
      if (action.agree) {
        if (!action.history) action.history = [];
        action.history.unshift({ who: $('#user_fullname').text().trim(), what: "agreed with", when: new Date() });
      }
      log.updateTeamAction(indicatorId, action);
      tap.updateAction(action);

      e.stopPropagation();
      e.preventDefault();
    }).on('click', '.btn-no', function(e) {
      var AGREE_STATUS = $(this).closest('tr').data('agree');
      var action = teamActionsObject[$(this).closest('tr').data('id')];

      if (AGREE_STATUS === false) {
        //editing reason
        tap.launchModal(data.selected, action.actionText, action.rejectedReason, action.rejectedReasonText, true, function() {
          if (!action.history) action.history = [];
          action.history.unshift({ who: $('#user_fullname').text().trim(), what: "disagreed with", when: new Date(), why: actionPlan.rejectedReasonText });
          action.agree = false;
          action.rejectedReason = actionPlan.rejectedReason;
          action.rejectedReasonText = actionPlan.rejectedReasonText;
          log.updateTeamAction(indicatorId, action);
          tap.updateAction(action);
        }, null, function() {
          action.agree = null;
          delete action.rejectedReason;
          delete action.rejectedReasonText;
          log.updateTeamAction(indicatorId, action);
          tap.updateAction(action);
        });
        e.stopPropagation();
        e.preventDefault();
      } else {
        //disagreeing
        tap.launchModal(data.selected, action.actionText, action.rejectedReason, action.rejectedReasonText, false, function() {
          if (!action.history) action.history = [];
          action.history.unshift({ who: $('#user_fullname').text().trim(), what: "disagreed with", when: new Date(), why: actionPlan.rejectedReasonText });
          action.agree = false;
          action.rejectedReason = actionPlan.rejectedReason;
          action.rejectedReasonText = actionPlan.rejectedReasonText;
          log.updateTeamAction(indicatorId, action);
          tap.updateAction(action);
        });
        e.stopPropagation();
        e.preventDefault();
      }
    });

    $('#advice-list').off('click', '.show-more-than-3');
    $('#advice-list').on('click', '.show-more-than-3', function(e) {
      tap.populateTeamSuggestedActions(pathwayId, pathwayStage, standard, true);
    });

    $('#advice-list').off('click', '.show-less-than-3');
    $('#advice-list').on('click', '.show-less-than-3', function(e) {
      tap.populateTeamSuggestedActions(pathwayId, pathwayStage, standard, false);
    });

    $('#advice-list').off('click', '.show-more');
    $('#advice-list').on('click', '.show-more', function(e) {
      var id = $(this).data("id");
      var elem = $('.show-more-row[data-id="' + id + '"]');
      if (elem.is(':visible')) {
        $('.show-more[data-id="' + id + '"]:first').show();
        elem.hide();
      } else {
        $('.show-more-row').hide();
        $('.show-more').show();
        $(this).hide();
        elem.show('fast');
      }
      // do not give a default action
      e.preventDefault();
      e.stopPropagation();
      return false;
    });

    $('#advice-list').off('click', 'tr.show-more-row a:not(.show-more)');
    $('#advice-list').on('click', 'tr.show-more-row a:not(.show-more)', function(e) {
      log.event("nice-link-clicked", window.location.hash, [{ key: "link", value: e.currentTarget.href }]);
      e.stopPropagation();
    });

    tap.loadAndPopulateIndividualSuggestedActions(pathwayId, pathwayStage, standard, false);
  },

  updateTeamSapRows: function() {
    /*$('#advice-list').add('#personalPlanTeam').find('.suggestion').each(function() {
      $(this).find('td').last().children().hide();
    });*/

    /*$('#advice-list').add('#personalPlanTeam').find('.cr-styled input[type=checkbox]').each(function() {
      if (this.checked) {
        $(this).parent().parent().parent().addClass('success');
      } else {
        $(this).parent().parent().parent().removeClass('success');
      }
    });*/

    /*$('#advice-list').add('#personalPlanTeam').find('.btn-undo').each(function() {
      $(this).parent().parent().addClass('success');
    });*/

    //no class - user not yet agreed/disagreed - no background / muted text
    //active - user agrees - green background / normal text
    //success - user completed - green background / strikethrough text
    //danger - user disagrees - red background / strikethrough text

    //TODO *b* inspect and amend danger and success to have more appropriate colours

    $('#advice-list').add('#personalPlanTeam').find('tr.suggestion').each(function() {
      var self = $(this);
      var id = self.data("id");
      var all = $('.show-more-row[data-id="' + id + '"],.suggestion[data-id="' + id + '"]');
      var any = false;
      self.find('.btn-toggle input[type=checkbox]:checked').each(function() {
        any = true;
        if (this.value === "yes") {
          all.removeClass('danger');
          all.addClass('active');
          //self.find('td').last().children().show();
          if (teamActionsObject[self.data("id")].history) {
            var tool = $(this).closest('tr').hasClass('success') ? "" : "<p>" + base.textFromHistory(teamActionsObject[self.data("id")].history[0]) + "</p><p>Click again to cancel</p>";
            $(this).parent().attr("title", tool).attr("data-original-title", tool).tooltip('fixTitle').tooltip('hide');
          } else {
            $(this).parent().attr("title", "You agreed - click again to cancel").tooltip('fixTitle').tooltip('hide');
          }
        } else {
          all.removeClass('active');
          all.addClass('danger');
          all.removeClass('success');
          if (teamActionsObject[self.data("id")].history) {
            $(this).parent().attr("title", "<p>" + base.textFromHistory(teamActionsObject[self.data("id")].history[0]) + "</p><p>Click again to edit/cancel</p>").tooltip('fixTitle').tooltip('hide');
          } else {
            $(this).parent().attr("title", "You disagreed - click again to edit/cancel").tooltip('fixTitle').tooltip('hide');
          }
        }
      });
      if (self.find('.btn-toggle input[type=checkbox]:not(:checked)').length == 1) {
        self.find('.btn-toggle input[type=checkbox]:not(:checked)').parent().addClass("inactive").attr("title", "").attr("data-original-title", "").tooltip('fixTitle').tooltip('hide');
      }
      if (!any) {
        all.removeClass('danger');
        all.removeClass('active');
        all.removeClass('success');

        self.find('.btn-toggle.btn-yes').attr("title", "Click to agree with this action and save it in your agreed actions list  ").tooltip('fixTitle').tooltip('hide');
        self.find('.btn-toggle.btn-no').attr("title", "Click to disagree with this action and remove it from your suggested actions list ").tooltip('fixTitle').tooltip('hide');
      }

      //base.wireUpTooltips();
    });
    base.wireUpTooltips();
  },

  displayPersonalisedTeamActionPlan: function(parentElem) {
    var tmpl = require('templates/action-plan-list');
    var userDefinedTeamActions = Object.keys(userDefinedTeamActionsObject).map(function(v) { return userDefinedTeamActionsObject[v]; });
    parentElem.html(tmpl({
      "hasSuggestions": userDefinedTeamActions && userDefinedTeamActions.length > 0,
      "suggestions": userDefinedTeamActions
    }));

    tap.updateTeamSapRows();
  },

  loadAndPopulateIndividualSuggestedActions: function(pathwayId, pathwayStage, standard, visible) {
    data.getTeamActionData(pathwayId && pathwayStage && standard ? [pathwayId, pathwayStage, standard].join(".") : "", function(err, a) {
      teamActionsObject = {};
      userDefinedTeamActionsObject = {};
      a.userDefinedActions.forEach(function(v) {
        userDefinedTeamActionsObject[v.actionTextId] = v;
      });
      teamActions = a.actions.map(function(v) {
        v.indicatorListText = v.indicatorList.map(function(vv) {
          return { id: vv, text: data.text.pathways[vv.split(".")[0]][vv.split(".")[1]].standards[vv.split(".")[2]].tabText };
        });
        if (v.agree !== true && v.agree !== false) v.agree = null;
        teamActionsObject[v.actionTextId] = v;
        return v;
      });
      tap.populateTeamSuggestedActions(pathwayId, pathwayStage, standard, visible);
    });
  },

  populateTeamSuggestedActions: function(pathwayId, pathwayStage, standard, visible) {
    var localData = {
      visible: visible
    };
    var fn = function(val) {
      return {
        "id": val,
        "subsection": subsection
      };
    };

    if (teamActions.length === 0) {
      localData.noSuggestions = true;
    } else {
      localData.suggestions = teamActions;
    }

    $('#advice').show();

    //base.createPanelShow(teamPanel, $('#advice-list'), localData);
    var tmpl = require("templates/team");
    $('#advice-list').html(tmpl(localData));

    //Wire up any clipboard stuff in the suggestions
    var isVision = $('#practice_system').text() === "Vision";
    $('#advice-list').find('span:contains("[COPY")').each(function() {
      var html = $(this).html();
      $(this).html(html.replace(/\[COPY:([^\]\.]*)(\.*)\]/g, (isVision ? '#$1$2' : '$1') + ' <button type="button" data-clipboard-text="' + (isVision ? '#$1$2' : '$1') + '" data-content="Copied!<br><strong>Use Ctrl + v to paste into ' + $('#practice_system').text() + '!</strong>" data-toggle="tooltip" data-placement="top" title="Copy ' + (isVision ? '#$1$2' : '$1') + ' to clipboard." class="btn btn-xs btn-default btn-copy"><span class="fa fa-clipboard"></span></button>'));
    });
    $('#advice-list').find('span:contains("[")').each(function() {
      var html = $(this).html();
      $(this).html(html.replace(/\[([^\]\.]*)(\.*)\]/g, ' <button type="button" data-clipboard-text="' + (isVision ? '#$1$2' : '$1') + '" data-content="Copied!<br><strong>Use Ctrl + v to paste into ' + $('#practice_system').text() + '!</strong>" data-toggle="tooltip" data-placement="top" title="Copy ' + (isVision ? '#$1$2' : '$1') + ' to clipboard." class="btn btn-xs btn-default btn-copy"><span class="fa fa-clipboard"></span></button>'));
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
      var tooltip = subsection ? "This action is suggested because PINGR classified this indcicator as:'" + desc + "'" : '';
      var newHtml = ' <i class="fa fa-info-circle fa-lg info-button clickable" data-toggle="tooltip" data-placement="right" title="' + tooltip + '"></i>';
      $(this).html(html.replace(/\[INFO\]/g, newHtml));
    });

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
        reasoning.replaceWith('Reasoning <button type="button" data-clipboard-text="' + content + '" data-content="Copied!<br><strong>Use Ctrl + v to paste into ' + $('#practice_system').text() + '!</strong>" data-toggle="tooltip" data-placement="top" title="Copy reasoning to clipboard." class="btn btn-xs btn-default btn-copy"><span class="fa fa-clipboard"></span></button>');
      }
    });

    base.setupClipboard('.btn-copy', true);

    tap.displayPersonalisedTeamActionPlan($('#personalPlanTeam'));
  },

  launchModal: function(label, value, rejectedReason, rejectedReasonText, isUndo, callbackOnSave, callbackOnCancel, callbackOnUndo) {
    var reasons = [{
      "reason": "We've already done this",
      "value": "done"
    }, {
      "reason": "It wouldn't work",
      "value": "nowork"
    }, {
      "reason": "Other",
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
      "placeholder": "Enter free-text here...",
      "reasons": reasons
    }, label, value, rejectedReasonText || null, callbackOnSave, callbackOnCancel, callbackOnUndo);
  }

};

module.exports = tap;
