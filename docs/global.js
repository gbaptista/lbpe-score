function createRadarChart(canvasId, datasets, labels) {
  const ctx = document.getElementById(canvasId).getContext('2d');
  new Chart(ctx, {
    type: 'radar',
    data: {
      labels: labels,
      datasets: datasets
    },
    options: {
      elements: {
        line: {
          borderWidth: 3
        },
        point: {
          radius: 4,
          hitRadius: 10,
          hoverRadius: 6
        }
      },
      scales: {
        r: {
          min: 0.0,
          max: 1.0,
          ticks: {
            callback: function(value, index, values) {
              return `${Math.round(value * 100.0)}%`;
            }
          }
        }
      },
      plugins: {
        datalabels: {
          color: '#666',
          // align: 'end',
          // anchor: 'end',
          formatter: (value, context) => {
            return '';
            // return `${Math.round(value * 100.0)}%`;
          }
        },
        tooltip: {
          enabled: true,
          callbacks: {
            label: function(context) {
              const labelIndex = context.dataIndex;
              const label = labels[labelIndex];
              const value = context.raw;
              
              return `${context.dataset.label}: ${Math.round(value * 100)}%`;
            }
          }
        }
      }
    }
  });
}

function createPercentageChart(canvasId, parsedData) {
  const colorScale = {
    'percentage': 'rgba(34, 139, 34, 0.6)'
  };

  const scoreLabels = {
    'percentage': 'Success Rate',
    'pricing/output/average-tokens-percentage': 'Conciseness',
    'pricing/output/average-USD-cost-10k-prompts-percentage': 'Cost Efficiency',
    'pricing/input/usd/1M-tokens-percentage': 'Cost Efficiency',
    'pricing/output/usd/1M-tokens-percentage': 'Cost Efficiency',
    'latency/CPS-percentage': 'Score',
    'latency-consolidated': 'Score',
    'stream-consolidated': 'Score',
  };


  const labels = Object.keys(parsedData).sort(
    (a, b) => parsedData[b].percentage - parsedData[a].percentage
  );

  const datasets = Object.keys(colorScale).map((score) => {
    return {
      label: scoreLabels[canvasId] || scoreLabels[score],
      data: labels.map(model => parsedData[model][score] || 0.0),
      backgroundColor: colorScale[score],
      borderWidth: 1
    };
  });

  const ctx = document.getElementById(canvasId).getContext('2d');
  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: labels,
      datasets: datasets
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      indexAxis: 'y',
      scales: {
        x: {
          stacked: false,
          max: 1.0,
        },
        y: {
          barThickness: 0.1,
          beginAtZero: true,

        }
      },
      plugins: {
        datalabels: {
          color: '#111',
          align: 'end',
          anchor: 'end',
          formatter: (value, context) => {
            return `${Math.round(value * 100.0)}%`;
          }
        }
      }
    }
  });
}

function createScoreChart(canvasId, parsedData) {
  const colorScale = {
    '0': 'rgba(255, 0, 0, 0.7)',
    '1': 'rgba(255, 69, 0, 0.6)',
    '2': 'rgba(255, 140, 0, 0.6)',
    '3': 'rgba(255, 165, 0, 0.6)',
    '4': 'rgba(34, 139, 34, 0.6)',
    '5': 'rgba(0, 128, 0, 0.6)'
  };

  const scoreLabels = {
    '0': 'Error',
    '1': 'Wrong',
    '2': 'Wrong',
    '3': 'Unsure',
    '4': 'Good',
    '5': 'Excellent'
  };

  const labels = Object.keys(parsedData).sort(
    (a, b) => parsedData[b][4] - parsedData[a][4]
  ).sort(
    (a, b) => parsedData[b][5] - parsedData[a][5]
  );

  const datasets = Object.keys(colorScale).map((score) => {
    return {
      label: scoreLabels[score],
      data: labels.map(model => parsedData[model][score]),
      backgroundColor: colorScale[score],
      borderWidth: 1
    };
  });

  const ctx = document.getElementById(canvasId).getContext('2d');
  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: labels,
      datasets: datasets
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      indexAxis: 'y',
      scales: {
        x: {
          stacked: false,
        },
        y: {
          beginAtZero: true
        }
      },
      plugins: {
        datalabels: {
          color: '#111',
          align: 'end',
          anchor: 'end',
          formatter: (value, context) => {
            return `${value}`;
          }
        }
      }
    }
  });
}

function createCustomScoreChart(canvasId, parsedData) {
  const colors = {
    'pricing/output/average-USD-cost-10k-prompts': 'rgba(61, 133, 198, 0.6)',
    'pricing/output/average-tokens': 'rgba(61, 133, 198, 0.6)',
    'pricing/input/usd/1M-tokens': 'rgba(61, 133, 198, 0.6)',
    'pricing/output/usd/1M-tokens': 'rgba(61, 133, 198, 0.6)',
    'latency/CPS': 'rgba(61, 133, 198, 0.6)',
    'stream/RTTFC': 'rgba(34, 139, 34, 0.6)',
    'stream/ARTTTC': 'rgba(34, 139, 34, 0.6)',
    'stream/ACRTFO': 'rgba(34, 139, 34, 0.6)',
  };

  const scoreLabels = {
    'pricing/output/average-USD-cost-10k-prompts': 'Average USD Cost per 10k Prompt',
    'pricing/output/average-tokens': 'Average Tokens',
    'pricing/input/usd/1M-tokens': 'USD / 1M tokens',
    'pricing/output/usd/1M-tokens': 'USD / 1M tokens',
    'latency/CPS': 'Characters / Second',
    'stream/RTTFC': 'Speed',
    'stream/ARTTTC': 'Speed',
    'stream/ACRTFO': 'Speed',
  };

  const usdFormatter = new Intl.NumberFormat('en-US', {
    style: 'currency',
    currency: 'USD',
    minimumFractionDigits: 0,
    maximumFractionDigits: 2
  });

  const formatters = {
    'pricing/output/average-tokens': (value, context) => { return Math.round(value); },
    'latency/CPS': (value, context) => { return Math.round(value); },
    'stream/RTTFC': (value, context) => { return `${Math.round(value * 100.0)}%`; },
    'stream/ARTTTC': (value, context) => { return `${Math.round(value * 100.0)}%`; },
    'stream/ACRTFO': (value, context) => { return `${Math.round(value * 100.0)}%`; },
    'pricing/input/usd/1M-tokens': (value, context) => {
      return usdFormatter.format(value);
    },
    'pricing/output/usd/1M-tokens': (value, context) => {
      return usdFormatter.format(value);
    },
    'pricing/output/average-USD-cost-10k-prompts': (value, context) => {
      return usdFormatter.format(value);
    },
  }

  const labels = Object.keys(parsedData).sort(
    (a, b) => parsedData[b] - parsedData[a]
  );

  const datasets = ['result'].map((score) => {
    return {
      label: scoreLabels[canvasId],
      data: labels.map(model => parsedData[model]),
      backgroundColor: colors[canvasId],
      borderWidth: 1
    };
  });

  const ctx = document.getElementById(canvasId).getContext('2d');
  new Chart(ctx, {
    type: 'bar',
    data: {
      labels: labels,
      datasets: datasets
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      indexAxis: 'y',
      scales: {
        x: {
          stacked: false,
        },
        y: {
          barThickness: 0.1,
          beginAtZero: true,

        }
      },
      plugins: {
        datalabels: {
          color: '#111',
          align: 'end',
          anchor: 'end',
          formatter: formatters[canvasId]
        }
      }
    }
  });
}

function loadAndCreateCharts() {
  Chart.register(ChartDataLabels);

  fetch('data/report.json?version=4f7b47c06b98ae515121548f553769d3')
    .then(response => response.json())
    .then(data => {
      for (const chartId in data['benchmarks']) {
        if (data['benchmarks'].hasOwnProperty(chartId)) {
          if (document.getElementById(chartId)) {
            if([
              'pricing/input/usd/1M-tokens', 'pricing/output/usd/1M-tokens',
              'pricing/output/average-tokens', 'pricing/output/average-USD-cost-10k-prompts',
              'latency/CPS', 'stream/RTTFC', 'stream/ARTTTC', 'stream/ACRTFO'
             ].includes(chartId)) {
              createCustomScoreChart(chartId, data['benchmarks'][chartId]);
            } else {
              createScoreChart(chartId, data['benchmarks'][chartId]);
            }
          } else {
            console.warn(`Canvas tag with id ${chartId} not found.`);
          }
        }
      }

      // ---------------------------------------------------------------------------------

      for (const chartIdRaw in data['percentage']) {
        const chartId = `${chartIdRaw}-percentage`;
        if (data['percentage'].hasOwnProperty(chartIdRaw)) {
          if (document.getElementById(chartId)) {
            createPercentageChart(chartId, data['percentage'][chartIdRaw]);
          } else {
            console.warn(`Canvas tag with id ${chartId} not found.`);
          }
        }
      }

      for (const chartIdRaw in data['consolidated']) {
        const chartId = `${chartIdRaw}-consolidated`;
        if (data['consolidated'].hasOwnProperty(chartIdRaw)) {
          if (document.getElementById(chartId)) {
            createPercentageChart(chartId, data['consolidated'][chartIdRaw]);
          } else {
            console.warn(`Canvas tag with id ${chartId} not found.`);
          }
        }
      }

      // ---------------------------------------------------------------------------------

      const radarData = data['radar'];
      const datasetsForConsolidatedChart = [];
      let radarLabels = [];

      // Hash for custom labels
      const customLabels = {
        'bafc': 'Back-and-Forth Conversations',
        'tools': 'Tools (Functions)',
        'mmlu': 'MMLU',
        'enem': 'ENEM',
        'pricing': 'Pricing',
        'stream': 'Streaming',
        'latency': 'Latency',
        'language': 'Polyglotism',
      };

      for (const model in radarData) {
        if (radarData.hasOwnProperty(model)) {
          if (radarLabels.length === 0) {
            radarLabels = Object.keys(radarData[model]).map(key => customLabels[key] || key);
          }

          const modelData = Object.keys(radarData[model]).map(key => {
            const value = radarData[model][key];
            return key === 'bafc' ? value.toFixed(2) : value;
          });

          const individualDataset = [{
            label: model,
            data: modelData,
            fill: true
          }];
          const individualCanvasId = `${model}-radar`;
          if (document.getElementById(individualCanvasId)) {
            createRadarChart(individualCanvasId, individualDataset, radarLabels);
          } else {
            console.warn(`Canvas tag with id ${individualCanvasId} not found.`);
          }

          datasetsForConsolidatedChart.push({
            label: model,
            data: modelData,
            fill: true
          });
        }
      }

      if (document.getElementById('consolidated-radar')) {
        createRadarChart('consolidated-radar', datasetsForConsolidatedChart, radarLabels);
      }
      // ---------------------------------------------------------------------------------
    })
    .catch(error => console.error('Error loading the JSON data:', error));
}

document.addEventListener('DOMContentLoaded', loadAndCreateCharts);
