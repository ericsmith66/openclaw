import { Controller } from "@hotwired/stimulus"
import Chart from "chart.js/auto"

export default class extends Controller {
  static values = {
    labels: Array,
    values: Array,
    label: String
  }

  connect() {
    console.log("[Chart] Controller connected")
    const ctx = this.element.getContext("2d")
    
    new Chart(ctx, {
      type: "line",
      data: {
        labels: this.labelsValue,
        datasets: [{
          label: this.labelValue,
          data: this.valuesValue,
          borderColor: "#007AFF",
          backgroundColor: "rgba(0, 122, 255, 0.1)",
          fill: true,
          tension: 0.4,
          pointRadius: 0,
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            mode: "index",
            intersect: false
          }
        },
        scales: {
          x: {
            display: false
          },
          y: {
            beginAtZero: true,
            grid: {
              color: "rgba(0, 0, 0, 0.05)"
            },
            ticks: {
              maxRotation: 0,
              font: {
                size: 10
              }
            }
          }
        }
      }
    })
  }
}
