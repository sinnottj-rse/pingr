var data = require('./data.js'),
  lookup = require('./lookup.js'),
  log = require('./log.js');

console.log("chart.js: data.lastloader= " + data.lastloader);
data.lastloader = "chart.js";

var cht = {

  destroyCharts: function(charts) {
    for (var i = 0; i < charts.length; i++) {
      if (lookup.charts[charts[i]]) {
        lookup.charts[charts[i]].destroy();
        delete lookup.charts[charts[i]];
      }
    }
  },

  drawTrendChart: function(patientId, pathwayId, pathwayStage, standard) {
    var i, j;
    cht.destroyCharts(['chart-demo-trend']);
    if (!data.patients[patientId][data[pathwayId][pathwayStage].standards[standard].chart[0]]) {
      $('#chart-demo-trend').html('No data for this patients');
      $('#chart-demo-trend').parent().find('.table-chart-toggle').hide();
      return;
    }

    var chartData = data.patients[patientId][data[pathwayId][pathwayStage].standards[standard].chart[0]];
    var tableData = [];
    for (i = 1; i < data.patients[patientId][data[pathwayId][pathwayStage].standards[standard].chart[0]][0].length; i++) {
      tableData.push({
        "item": data.patients[patientId][data[pathwayId][pathwayStage].standards[standard].chart[0]][1][0],
        "value": data.patients[patientId][data[pathwayId][pathwayStage].standards[standard].chart[0]][1][i],
        "date": data.patients[patientId][data[pathwayId][pathwayStage].standards[standard].chart[0]][0][i]
      });
    }
    for (i = 1; i < data[pathwayId][pathwayStage].standards[standard].chart.length; i++) {
      chartData.push(data.patients[patientId][data[pathwayId][pathwayStage].standards[standard].chart[i]][1]); //RW TODO assumption here that all dates are the same
      for (j = 1; j < data.patients[patientId][data[pathwayId][pathwayStage].standards[standard].chart[0]][0].length; j++) {
        tableData.push({
          "item": data.patients[patientId][data[pathwayId][pathwayStage].standards[standard].chart[i]][1][0],
          "value": data.patients[patientId][data[pathwayId][pathwayStage].standards[standard].chart[i]][1][j],
          "date": data.patients[patientId][data[pathwayId][pathwayStage].standards[standard].chart[0]][0][j]
        });
      }
    }
    var chartOptions = {
      bindto: '#chart-demo-trend',
      data: {
        xs: {},
        classes: {},
        columns: chartData.slice()
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
            fit: false,
            format: '%d-%m-%Y',
            count: 5
          },
          max: new Date()
        },
        y: {
          label: {
            text: data[pathwayId][pathwayStage].standards[standard].chartUnits,
            position: 'outer-middle'
          }
        }
      }
    };

    var maxValue = 0;
    var standardItems = [];

    for (i = 1; i < chartOptions.data.columns.length; i++) {
      chartOptions.data.xs[chartOptions.data.columns[i][0]] = "x";
      standardItems.push(chartOptions.data.columns[i][0]);

      for (j = 1; j < chartOptions.data.columns[i].length; j++) {
        if (parseFloat(chartOptions.data.columns[i][j]) > maxValue) maxValue = parseFloat(chartOptions.data.columns[i][j]);
      }
    }

    chartOptions.tooltip = {
      format: {
        value: function(value, ratio, id) {
          var text = standardItems.indexOf(id) > -1 ? value : "";
          return text;
        }
      }
    };

    var lines = null;
    var axisnum = 1;
    if (data.patients[patientId].contacts) {
      for (i = 0; i < data.patients[patientId].contacts.length; i++) {
        chartOptions.data.classes[data.patients[patientId].contacts[i].text] = 'larger';
        if (!chartOptions.data.xs[data.patients[patientId].contacts[i].text]) {
          chartOptions.data.xs[data.patients[patientId].contacts[i].text] = "x" + axisnum;
          chartOptions.data.columns.push(["x" + axisnum, data.patients[patientId].contacts[i].value]);
          chartOptions.data.columns.push([data.patients[patientId].contacts[i].text, (maxValue * 1.1).toString()]);
          axisnum++;
        } else {
          var axis = chartOptions.data.xs[data.patients[patientId].contacts[i].text];
          for (j = 1; j < chartOptions.data.columns.length; j++) {
            if (chartOptions.data.columns[j][0] === axis) {
              chartOptions.data.columns[j].push(data.patients[patientId].contacts[i].value);
            } else if (chartOptions.data.columns[j][0] === data.patients[patientId].contacts[i].text) {
              chartOptions.data.columns[j].push((maxValue * 1.1).toString());
            }
          }
        }
        tableData.push({
          "item": "Event",
          "value": data.patients[patientId].contacts[i].text,
          "date": data.patients[patientId].contacts[i].value
        });
      }
    }

    var patientEvents = log.getEvents().filter(function(val) {
      return val.id === patientId;
    });
    if (patientEvents.length > 0) {

      for (i = 0; i < patientEvents.length; i++) {
        chartOptions.data.classes[patientEvents[i].name] = 'larger';
        if (!chartOptions.data.xs[patientEvents[i].name]) {
          chartOptions.data.xs[patientEvents[i].name] = "x" + axisnum;
          chartOptions.data.columns.push(["x" + axisnum, patientEvents[i].date.substr(0, 10)]);
          chartOptions.data.columns.push([patientEvents[i].name, (maxValue * 1.1).toString()]);
          axisnum++;
        } else {
          var axis2 = chartOptions.data.xs[patientEvents[i].name];
          for (j = 1; j < chartOptions.data.columns.length; j++) {
            if (chartOptions.data.columns[j][0] === axis2) {
              chartOptions.data.columns[j].push(patientEvents[i].date.substr(0, 10));
            } else if (chartOptions.data.columns[j][0] === patientEvents[i].name) {
              chartOptions.data.columns[j].push((maxValue * 1.1).toString());
            }
          }
        }
        tableData.push({
          "item": "Event",
          "value": patientEvents[i].name,
          "date": patientEvents[i].date.substr(0, 10)
        });
      }
    }

    tableData.sort(function(a, b) {
      if (a.date === b.date) return 0;
      else return a.date < b.date ? 1 : -1;
    });
    //draw Table
    $('#table-demo-trend').html(Mustache.render($('#value-trend-panel-table').html(), {
      "items": tableData
    }, {
      "item-row": $('#value-trend-panel-table-row').html()
    }));

    //draw charts in separate thread and with delay to stop sluggish appearance
    setTimeout(function() {
      lookup.charts['chart-demo-trend'] = c3.generate(chartOptions);
    }, 1);
  },

  selectPieSlice: function(chart, d) {
    lookup.chartClicked = true;
    $('#' + chart + ' path.c3-bar').attr('class', function(index, classNames) {
      return classNames + ' _unselected_';
    });
    lookup.charts[chart].select([d.id], [d.index], true);

    farRightPanel.fadeOut(200, function() {
      var template = $('#patient-panel-placeholder').html();
      farRightPanel.html(Mustache.render(template)).show();
    });
  },

  drawOverviewChart: function(pathwayId, pathwayStage, enableHover) {
    cht.destroyCharts([pathwayStage + '-chart']);
    setTimeout(function() {
      lookup.charts[pathwayStage + '-chart'] = c3.generate({
        bindto: '#' + pathwayStage + '-chart',
        data: {
          x: 'x',
          columns: data[pathwayId][pathwayStage].trend
        },
        zoom: {
          enabled: true
        },
        tooltip: {
          format: {
            title: function(x) {
              return x.toDateString() + (enableHover ? '<br>Click for more detail' : '');
            },
            value: function(value) {
              return enableHover ? value + '%' : undefined;
            }
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
          y: {
            min: 0,
            label: {
              text: 'Proportion (%)',
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
      });
    }, 1);
  },

  drawBenchmarkChart: function(element, data) {
    cht.destroyCharts([element + '-chart']);
    setTimeout(function() {
      lookup.charts[element + '-chart'] = c3.generate({
        bindto: '#' + element,
        size: {
          height: 200
        },
        data: data,
        axis: {
          x: {
            type: 'category',
            tick: {
              rotate: 60,
              multiline: false
            }
          },
          y: {
            label: {
              text: '% of patients meeting the target',
              position: 'outer-middle'
            }
          }
        },
        grid: {
          y: {
            show: true
          }
        }
      });
    }, 1);
  },

  drawPerformanceTrendChart: function(element, data) {
    cht.destroyCharts([element + '-chart']);
    setTimeout(function() {
      lookup.charts[element + '-chart'] = c3.generate({
        bindto: '#' + element,
        size: {
          height: 200
        },
        data: data,
        axis: {
          x: {
            type: 'timeseries',
            tick: {
              format: '%Y-%m-%d',
              rotate: 60,
              multiline: false
            },
            height: 60
          },
          y: {
            label: {
              text: "Performance",
              position: 'outer-middle'
            }
          }
        },
        grid: {
          x: {
            show: true
          },
          y: {
            show: true
          }
        }
      });
    }, 1);
  },

  drawBenchmarkChartHC: function(element, data) {
    $('#' + element).highcharts({
      chart: {
        type: 'column',
        height: 300
      },
      title: {
        text: ''
      },
      xAxis: {
        categories: [
                    'P1',
                    'P2',
                    'P3',
                    'P4',
                    'P5',
                    'P6',
                    'YOU',
                    'P7',
                    'P8',
                    'P9',
                    'P10',
                    'P11'
                ],
        crosshair: true
      },
      yAxis: {
        min: 0,
        max: 100,
        title: {
          text: '% patients meeting target'
        }
      },
      tooltip: {
        headerFormat: '<span style="font-size:10px">Practice: <b>{point.key}</b></span><table>',
        pointFormat: '<tr><td style="color:{series.color};padding:0">{series.name}: </td>' +
          '<td style="padding:0"><b>{point.y:.1f}%</b></td></tr>',
        footerFormat: '</table>',
        shared: true,
        useHTML: true
      },
      plotOptions: {
        column: {
          pointPadding: 0.2,
          borderWidth: 0
        }
      },
      legend: {
        enabled: false
      },
      series: [{
        name: 'Performance',
        data: [49.9, 71.5, 16.4, 29.2, 44.0, 76.0, {
          y: 35.6,
          color: "red"
        }, 48.5, 26.4, 94.1, 95.6, 54.4]
      }]
    });
  },

  drawPerformanceTrendChartHC: function(element, data, selectSeriesFn) {

    var series = [];

    data.forEach(function(v, i) {
      if (i === 0) return;
      series.push({
        type: 'line',
        name: v[0],
        data: []
      });
    });
    data[0].forEach(function(v, i) {
      if (i === 0) return;
      var time = new Date(v).getTime();
      series.forEach(function(vv, ii) {
        vv.data.push([time, +data[ii + 1][i]]);
      });
    });

    $('#' + element).highcharts({
      chart: {
        zoomType: 'x',
        height: 300
      },
      title: {
        text: ''
      },
      subtitle: {
        text: document.ontouchstart === undefined ?
          'Click and drag in the plot area to zoom in' : 'Pinch the chart to zoom in'
      },
      xAxis: {
        type: 'datetime'
      },
      yAxis: {
        title: {
          text: 'Quality standard performance'
        }
      },
      legend: {
        enabled: true
      },

      plotOptions: {
        series: {
          states: {
            /*hover : {
              enabled: false
            },*/
            select: {
              lineWidthPlus: 2
            },
            faded: {
              lineWidth: 1
            }
          },
          events: {

            legendItemClick: function(event) {
              var numSeries = this.chart.series.length;
              var numVisible = this.chart.series.filter(function(v){return v.visible;}).length;

              if (this.visible && numVisible === 1) {
                //show all
                this.chart.series.forEach(function(series) {
                  series.show();
                });
                selectSeriesFn();
              } else {
                this.chart.series.forEach(function(series) {
                  series.hide();
                });
                this.show();
                selectSeriesFn(this.name);
              }

              return false;
            }
          }
        }
      },

      series: series
    });
  }

};

module.exports = cht;
