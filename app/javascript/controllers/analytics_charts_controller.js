import { Controller } from "@hotwired/stimulus";
import Chart from "chart.js/auto";

export default class extends Controller {
  static targets = [
    "visitsChart",
    "pagesChart",
    "sourcesChart",
    "devicesChart",
    "browsersChart",
    "osChart",
    "hourlyChart",
    "engagementChart",
    "conversionChart",
    "geographicChart",
    "clickDestinationsChart",
    "clickedElementsChart",
    "clicksByPageChart",
    "clickTypesChart",
  ];

  connect() {
    this.charts = [];
    this.initializeCharts();
  }

  disconnect() {
    this.charts.forEach((chart) => chart.destroy());
    this.charts = [];
  }

  initializeCharts() {
    if (this.hasVisitsChartTarget) this.initVisitsChart();
    if (this.hasPagesChartTarget) this.initPagesChart();
    if (this.hasSourcesChartTarget) this.initSourcesChart();
    if (this.hasDevicesChartTarget) this.initDevicesChart();
    if (this.hasBrowsersChartTarget) this.initBrowsersChart();
    if (this.hasOsChartTarget) this.initOsChart();
    if (this.hasHourlyChartTarget) this.initHourlyChart();
    if (this.hasEngagementChartTarget) this.initEngagementChart();
    if (this.hasConversionChartTarget) this.initConversionChart();
    if (this.hasGeographicChartTarget) this.initGeographicChart();
    if (this.hasClickDestinationsChartTarget) this.initClickDestinationsChart();
    if (this.hasClickedElementsChartTarget) this.initClickedElementsChart();
    if (this.hasClicksByPageChartTarget) this.initClicksByPageChart();
    if (this.hasClickTypesChartTarget) this.initClickTypesChart();
  }

  initVisitsChart() {
    const data = JSON.parse(this.visitsChartTarget.dataset.chartData || "{}");

    const ctx = this.visitsChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "line",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            label: "Vizite",
            data: data.visits || [],
            borderColor: "#4A6775",
            backgroundColor: "rgba(74, 103, 117, 0.1)",
            fill: true,
            tension: 0.4,
            borderWidth: 3,
            pointRadius: 4,
            pointHoverRadius: 6,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
            callbacks: {
              label: (context) => ` ${context.parsed.y} vizite`,
            },
          },
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              precision: 0,
              font: { size: 12 },
            },
            grid: {
              color: "rgba(0, 0, 0, 0.05)",
            },
          },
          x: {
            ticks: {
              font: { size: 11 },
            },
            grid: {
              display: false,
            },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initPagesChart() {
    const data = JSON.parse(this.pagesChartTarget.dataset.chartData || "{}");

    const ctx = this.pagesChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            label: "Vizualizări",
            data: data.views || [],
            backgroundColor: [
              "#4A6775",
              "#6B8E9F",
              "#8DB3C5",
              "#AECEDC",
              "#CFE7F1",
            ].slice(0, data.labels?.length || 0),
            borderWidth: 0,
            borderRadius: 6,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: "y",
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
            callbacks: {
              label: (context) => ` ${context.parsed.x} vizualizări`,
            },
          },
        },
        scales: {
          x: {
            beginAtZero: true,
            ticks: {
              precision: 0,
              font: { size: 12 },
            },
            grid: {
              color: "rgba(0, 0, 0, 0.05)",
            },
          },
          y: {
            ticks: {
              font: { size: 11 },
            },
            grid: {
              display: false,
            },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initSourcesChart() {
    const data = JSON.parse(this.sourcesChartTarget.dataset.chartData || "{}");

    const ctx = this.sourcesChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "doughnut",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            data: data.values || [],
            backgroundColor: [
              "#4A6775",
              "#5A7F93",
              "#6B97B1",
              "#7CAFCF",
              "#8DC7ED",
              "#9FDFFF",
            ],
            borderWidth: 2,
            borderColor: "#fff",
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "right",
            labels: {
              font: { size: 12 },
              padding: 15,
              usePointStyle: true,
              pointStyle: "circle",
            },
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
            callbacks: {
              label: (context) => {
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const percentage = ((context.parsed / total) * 100).toFixed(1);
                return ` ${context.label}: ${context.parsed} (${percentage}%)`;
              },
            },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initDevicesChart() {
    const data = JSON.parse(this.devicesChartTarget.dataset.chartData || "{}");

    const ctx = this.devicesChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "pie",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            data: data.values || [],
            backgroundColor: ["#4A6775", "#6B8E9F", "#8DB3C5", "#AECEDC"],
            borderWidth: 2,
            borderColor: "#fff",
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              font: { size: 12 },
              padding: 12,
              usePointStyle: true,
              pointStyle: "circle",
            },
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
            callbacks: {
              label: (context) => {
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const percentage = ((context.parsed / total) * 100).toFixed(1);
                return ` ${context.label}: ${context.parsed} (${percentage}%)`;
              },
            },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initBrowsersChart() {
    const data = JSON.parse(this.browsersChartTarget.dataset.chartData || "{}");

    const ctx = this.browsersChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            label: "Utilizatori",
            data: data.values || [],
            backgroundColor: "#4A6775",
            borderRadius: 6,
            borderWidth: 0,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
            callbacks: {
              label: (context) => ` ${context.parsed.y} utilizatori`,
            },
          },
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              precision: 0,
              font: { size: 12 },
            },
            grid: {
              color: "rgba(0, 0, 0, 0.05)",
            },
          },
          x: {
            ticks: {
              font: { size: 11 },
            },
            grid: {
              display: false,
            },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initOsChart() {
    const data = JSON.parse(this.osChartTarget.dataset.chartData || "{}");

    const ctx = this.osChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "doughnut",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            data: data.values || [],
            backgroundColor: [
              "#4A6775",
              "#5A7F93",
              "#6B97B1",
              "#7CAFCF",
              "#8DC7ED",
            ],
            borderWidth: 2,
            borderColor: "#fff",
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: {
              font: { size: 12 },
              padding: 12,
              usePointStyle: true,
              pointStyle: "circle",
            },
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
            callbacks: {
              label: (context) => {
                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                const percentage = ((context.parsed / total) * 100).toFixed(1);
                return ` ${context.label}: ${context.parsed} (${percentage}%)`;
              },
            },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initHourlyChart() {
    const data = JSON.parse(this.hourlyChartTarget.dataset.chartData || "{}");

    const ctx = this.hourlyChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "line",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            label: "Vizite",
            data: data.values || [],
            borderColor: "#6B8E9F",
            backgroundColor: "rgba(107, 142, 159, 0.1)",
            fill: true,
            tension: 0.4,
            borderWidth: 2,
            pointRadius: 3,
            pointHoverRadius: 5,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
            callbacks: {
              label: (context) => ` ${context.parsed.y} vizite`,
            },
          },
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              precision: 0,
              font: { size: 11 },
            },
            grid: {
              color: "rgba(0, 0, 0, 0.05)",
            },
          },
          x: {
            ticks: {
              font: { size: 10 },
            },
            grid: {
              display: false,
            },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initEngagementChart() {
    const data = JSON.parse(
      this.engagementChartTarget.dataset.chartData || "{}"
    );

    const ctx = this.engagementChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            label: "Pagini/Sesiune",
            data: data.pagesPerSession || [],
            backgroundColor: "#4A6775",
            borderRadius: 6,
          },
          {
            label: "Durată (min)",
            data: data.duration || [],
            backgroundColor: "#8DB3C5",
            borderRadius: 6,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "top",
            labels: {
              font: { size: 12 },
              usePointStyle: true,
              pointStyle: "circle",
            },
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
          },
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              precision: 1,
              font: { size: 11 },
            },
            grid: {
              color: "rgba(0, 0, 0, 0.05)",
            },
          },
          x: {
            ticks: {
              font: { size: 11 },
            },
            grid: {
              display: false,
            },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initConversionChart() {
    const data = JSON.parse(
      this.conversionChartTarget.dataset.chartData || "{}"
    );

    const ctx = this.conversionChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            label: "Conversii",
            data: data.values || [],
            backgroundColor: ["#4A6775", "#6B8E9F", "#8DB3C5", "#AECEDC"],
            borderRadius: 6,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: "y",
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
          },
        },
        scales: {
          x: {
            beginAtZero: true,
            ticks: {
              precision: 0,
              font: { size: 12 },
            },
            grid: {
              color: "rgba(0, 0, 0, 0.05)",
            },
          },
          y: {
            ticks: {
              font: { size: 11 },
            },
            grid: {
              display: false,
            },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initGeographicChart() {
    const data = JSON.parse(
      this.geographicChartTarget.dataset.chartData || "{}"
    );

    const ctx = this.geographicChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "bar",
      data: {
        labels: data.labels || [],
        datasets: [
          {
            label: "Vizitatori",
            data: data.values || [],
            backgroundColor: "#4A6775",
            borderRadius: 6,
          },
        ],
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: "y",
        plugins: {
          legend: {
            display: false,
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
            callbacks: {
              label: (context) => ` ${context.parsed.x} vizitatori`,
            },
          },
        },
        scales: {
          x: {
            beginAtZero: true,
            ticks: {
              precision: 0,
              font: { size: 12 },
            },
            grid: {
              color: "rgba(0, 0, 0, 0.05)",
            },
          },
          y: {
            ticks: {
              font: { size: 11 },
            },
            grid: {
              display: false,
            },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initClickDestinationsChart() {
    const data = JSON.parse(
      this.clickDestinationsChartTarget.dataset.chartData || "{}"
    );

    const ctx = this.clickDestinationsChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "bar",
      data: data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
          },
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: { precision: 0, font: { size: 12 } },
            grid: { color: "rgba(0, 0, 0, 0.05)" },
          },
          x: {
            ticks: { font: { size: 11 }, maxRotation: 45, minRotation: 45 },
            grid: { display: false },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initClickedElementsChart() {
    const data = JSON.parse(
      this.clickedElementsChartTarget.dataset.chartData || "{}"
    );

    const ctx = this.clickedElementsChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "bar",
      data: data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: "y",
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
          },
        },
        scales: {
          x: {
            beginAtZero: true,
            ticks: { precision: 0, font: { size: 12 } },
            grid: { color: "rgba(0, 0, 0, 0.05)" },
          },
          y: {
            ticks: { font: { size: 11 } },
            grid: { display: false },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initClicksByPageChart() {
    const data = JSON.parse(
      this.clicksByPageChartTarget.dataset.chartData || "{}"
    );

    const ctx = this.clicksByPageChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "bar",
      data: data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
          },
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: { precision: 0, font: { size: 12 } },
            grid: { color: "rgba(0, 0, 0, 0.05)" },
          },
          x: {
            ticks: { font: { size: 11 }, maxRotation: 45, minRotation: 45 },
            grid: { display: false },
          },
        },
      },
    });
    this.charts.push(chart);
  }

  initClickTypesChart() {
    const data = JSON.parse(
      this.clickTypesChartTarget.dataset.chartData || "{}"
    );

    const ctx = this.clickTypesChartTarget.getContext("2d");
    const chart = new Chart(ctx, {
      type: "doughnut",
      data: data,
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: "bottom",
            labels: { padding: 20, font: { size: 13 } },
          },
          tooltip: {
            backgroundColor: "rgba(0, 0, 0, 0.8)",
            padding: 12,
            titleFont: { size: 14, weight: "600" },
            bodyFont: { size: 13 },
          },
        },
      },
    });
    this.charts.push(chart);
  }
}
