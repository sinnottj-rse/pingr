const $ = require('jquery');
const base = require('./base');
const template = require('./template');

let ignoreThisEvent = false;
let isNextEnabled = true;
let isAnimating = false;

const arrangeMask = (maskType, target, padding) => {
  const targetLeft = target.offset().left;
  const targetRight = targetLeft + target.outerWidth();
  const targetTop = target.offset().top;
  const targetBottom = targetTop + target.outerHeight();
  $(`.tutorial-${maskType}-mask.tutorial-mask-left`).css('width', targetLeft - padding);
  $(`.tutorial-${maskType}-mask.tutorial-mask-right`).css('left', targetRight + padding);

  $(`.tutorial-${maskType}-mask.tutorial-mask-top`).css('height', targetTop - padding);
  $(`.tutorial-${maskType}-mask.tutorial-mask-top`).css('left', targetLeft - padding);
  $(`.tutorial-${maskType}-mask.tutorial-mask-top`).css('width', (targetRight - targetLeft) + (2 * padding));

  $(`.tutorial-${maskType}-mask.tutorial-mask-bottom`).css('top', targetBottom + padding);
  $(`.tutorial-${maskType}-mask.tutorial-mask-bottom`).css('left', targetLeft - padding);
  $(`.tutorial-${maskType}-mask.tutorial-mask-bottom`).css('width', (targetRight - targetLeft) + (2 * padding));
  $(`.tutorial-${maskType}-mask`).show();
};

const showTotalMask = () => {
  $('.tutorial-highlight-mask.tutorial-mask-right').css('left', 0).show();
};
const hideTotalMask = () => {
  $('.tutorial-highlight-mask').hide();
  $('.tutorial-disabling-mask').hide();
};
const showMenuMask = () => {
  $('.tutorial-menu-mask').show();
};
const hideMenuMask = () => {
  $('.tutorial-menu-mask').hide();
};

const tabMapping = {
  overviewTab: ['overview'],
  indicatorTab: ['overview', 'indicator'],
  patientTab: ['overview', 'patient'],
  actionTab: ['overview', 'action'],
};

const beforeLegStart = (leg, bus) => {
  isAnimating = true;
  if (!leg.$target.is(':visible')) {
    console.log('not visible - lets check the rawData.el');
    if ($(leg.rawData.el).is(':visible')) {
      console.log('its visible. lets go!');
      leg.$target = $(leg.rawData.el);
    } else {
      console.log('not visible either, wait 100ms and try again');
      setTimeout(() => {
        beforeLegStart(leg, bus);
      }, 100);
      return false;
    }
  }
  hideTotalMask();
  console.log('visible');
  if (leg.rawData.moveableElement) {
    leg.$target = $(leg.rawData.el);
  }
  if (leg.rawData.scrollElement) {
    $(leg.rawData.scrollElement).scrollTop(leg.rawData.scrollValue);
  }
  if (leg.rawData.waitFor) {
    isNextEnabled = false;
    $(leg.rawData.waitFor).on(leg.rawData.waitForEvent, () => {
      if (!ignoreThisEvent) {
        setTimeout(() => {
          bus.next();
        }, 400);
      }
    });
    if (leg.rawData.waitForIgnore) {
      $(leg.rawData.waitForIgnore).on(leg.rawData.waitForEvent, () => {
        ignoreThisEvent = true;
        setTimeout(() => {
          ignoreThisEvent = false;
        }, 100);
      });
    }
  }
  if (leg.rawData.highlight) {
    arrangeMask('highlight', leg.$target, 2);
  }
  if (leg.rawData.mask) {
    showTotalMask();
  }
  if (leg.rawData.enableEl) {
    arrangeMask('disabling', $(leg.rawData.enableEl), 0);
  } else {
    $('.tutorial-disabling-mask.tutorial-mask-right').css('left', 0).show();
  }
  leg.reposition();
  leg.$el
    .css({ visibility: 'visible', opacity: 0, zIndex: 9999 })
    .animate({ opacity: 1.0 }, 600, () => {
      leg.show();
      isAnimating = false;
    });
  return false;
};

const tourbusParams = {
  leg: { margin: 25 },
  // called when the tour starts
  onDepart(bus) {
    $(document).off('keyup').on('keyup', (e) => {
      switch (e.keyCode) {
        // enter
        // case 13:
        // right arrow
        case 39:
          if (isNextEnabled && !isAnimating) bus.next();
          break;
        // left arrow
        case 37:
        // backspace
        // case 8:
          if (!isAnimating) bus.prev();
          break;
        // escape
        case 27:
          bus.stop();
          break;
        default:
      }
    });
  },
  // called when the tour is stopped for any reason
  onStop() {
    hideTotalMask();
    $(document).off('keyup');
  },
  // called before switching to a leg
  onLegStart(leg, bus) {
    return beforeLegStart(leg, bus);
  },
  // called before switching _from_ a leg
  onLegEnd(leg) {
    if (leg.rawData.waitFor) {
      isNextEnabled = true;
      $(leg.rawData.waitFor).off(leg.rawData.waitForEvent);
    }
  },
};

const hideMenu = () => {
  hideMenuMask();
  $('.tutorial-menu').hide();
};

const showMenu = () => {
  $('.tutorial-menu').show();

  $('.tutorial-menu li').off('click').on('click', (e) => {
    const selectedTutorial = $(e.currentTarget).data('id');

    if (selectedTutorial === 'overview') {
      // navigate to overview tab first
      template.loadContent('#overview');
    }

    hideMenu();

    const tour = $.tourbus(`#tutorial-${selectedTutorial}`, tourbusParams);
    tour.depart();
  });
};

const getAvailableTutorials = () => {
  const currentTab = base.getTab();
  const availableTutorials = tabMapping[currentTab];
  return availableTutorials;
};

const showTutorials = (tutorials = []) => {
  if (tutorials.length === 1) {
    // start tutorial
    const tour = $.tourbus(`#tutorial-${tutorials[0]}`, tourbusParams);
    tour.depart();
  } else if (tutorials.length > 1) {
    // show main mask
    showMenuMask();
    // hide all tutorials from menu
    $('.tutorial-menu li').hide();

    // show available tutorials
    tutorials.forEach((t) => {
      $(`.tutorial-menu li[data-id=${t}]`).show();
    });
    showMenu();
    $('.tutorial-close').on('click', () => {
      hideMenu();
    });
    $(document).off('keyup').on('keyup', (e) => {
      switch (e.keyCode) {
        // escape
        case 27:
          hideMenu();
          break;
        default:
      }
    });
  } else {
    // starting not on a tab so let's just go to the overview
    template.loadContent('#overview');

    const tour = $.tourbus('#tutorial-overview', tourbusParams);
    tour.depart();
  }
};

const wireUpTutorialLink = () => {
  $('#tutorial').off('click').on('click', (clickEvent) => {
    clickEvent.preventDefault();
    const availableTutorials = getAvailableTutorials();
    showTutorials(availableTutorials);
  });
};

exports.initialize = wireUpTutorialLink;
