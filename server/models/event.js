var mongoose = require('mongoose'),
  Schema = mongoose.Schema;

var EventSchema = new Schema({
  sessionId : String,
  date: { type: Date, default: Date.now },
  user : String,
  type : String,
  data : [{ _id:false, key : String, value : String }],
  url: String,
  xpath: String
});

module.exports = mongoose.model('Event', EventSchema);
