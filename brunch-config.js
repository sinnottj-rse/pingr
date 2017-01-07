module.exports = {
  // See http://brunch.io for documentation.
  // see http://brunch.io/docs/config for syntax and setup
  paths: {
    public: 'dist',
      watched: ['app','vendor']
  },

  files: {
    javascripts: {
      joinTo: {
        'libraries.js': /^(?!(app|server)\/)/
      },
      order: {
        before: [
          'vendor/scripts/bootstrap.js'
          ]
      },
      entryPoints: {
        'app/script.js': {
          'app.js': /^app\//
        }
      }
    },
    stylesheets: {
      joinTo: {
        'app.css' : /^app\/styles\/style/,
        'ct_dash.css' : /^app\/styles\/dash/
      }
    },

    templates: {
      joinTo: 'app.js'
      
    }
  }
};
