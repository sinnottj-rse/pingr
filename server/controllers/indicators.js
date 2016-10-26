var Indicator = require('../models/indicator');

module.exports = {

  //Get list of indicators for a single practice - for use on the overview screen
  list: function(practiceId, done) {
    Indicator.find({ practiceId: practiceId }, function(err, indicators) {
      if (err) {
        console.log(err);
        return done(new Error("Error finding indicator list for practice: " + practiceId));
      }
      if (!indicators) {
        console.log('Error finding indicator list for practice:  ' + practiceId);
        return done(null, false);
      } else {
        done(null, indicators);
      }
    });
  },

  //Get single indicator for a given practice
  get: function(practiceId, indicatorId, done) {
    Indicator.findOne({ practiceId: practiceId, id: indicatorId }, function(err, indicator) {
      if (err) {
        console.log(err);
        return done(new Error("Error finding indicator: " + indicatorId + " for practice: " + practiceId));
      }
      if (!indicator) {
        console.log("Error finding indicator: " + indicatorId + " for practice: " + practiceId);
        return done(null, false);
      } else {
        done(null, indicator);
      }
    });
  },

  //Get benchmark data for an indicator
  getBenchmark: function(indicatorId, done) {
    Indicator.find({ id: indicatorId }, function(err, indicators) {
      if (err) {
        console.log(err);
        return done(new Error("Error finding indicators for: " + indicatorId));
      }
      if (!indicators) {
        console.log('Error finding indicators for:  ' + indicatorId);
        return done(null, false);
      } else {
        var benchmark = indicators.map(function(v) {
          return {
            practiceId: v.practiceId,
            numerator: +v.values[1][v.values[1].length - 1],
            denominator: +v.values[2][v.values[2].length - 1]
          };
        });
        done(null, benchmark);
      }
    });
  },

  //Get trend data for a practice and an indicator
  getTrend: function(practiceId, indicatorId, done) {
    Indicator.findOne({ practiceId: practiceId, id: indicatorId }, { values: 1 }, function(err, indicator) {
      if (err) {
        console.log(err);
        return done(new Error("Error finding trend for practice: " + practiceId + " and indicator: " + indicatorId));
      }
      if (!indicator) {
        console.log("Error finding trend for practice: " + practiceId + " and indicator: " + indicatorId);
        return done(null, false);
      } else {
        done(null, indicator.values);
      }
    });
  }

};