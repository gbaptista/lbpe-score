function createPercentageChart(canvasId, parsedData) {
  const colorScale = {
    'percentage': 'rgba(34, 139, 34, 0.6)'
  };

  const scoreLabels = {
    'percentage': 'Success Rate',
  };

  const labels = Object.keys(parsedData);

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

  const labels = Object.keys(parsedData);

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

function loadAndCreateCharts() {
  Chart.register(ChartDataLabels);

  fetch('data/report.json')
    .then(response => response.json())
    .then(data => {
      for (const chartId in data) {
        if (data.hasOwnProperty(chartId)) {
          if (document.getElementById(chartId)) {
            createScoreChart(chartId, data[chartId]);
          } else {
            console.warn(`Canvas tag with id ${chartId} not found.`);
          }
        }
      }

      for (const chartIdRaw in data['percentage']) {
        const chartId = `${chartIdRaw}-percentage`;
        if (data.hasOwnProperty(chartIdRaw)) {
          if (document.getElementById(chartId)) {
            createPercentageChart(chartId, data['percentage'][chartIdRaw]);
          } else {
            console.warn(`Canvas tag with id ${chartId} not found.`);
          }
        }
      }
    })
    .catch(error => console.error('Error loading the JSON data:', error));
}

document.addEventListener('DOMContentLoaded', loadAndCreateCharts);
