import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}

Hooks.CopyToClipboard = {
  mounted() {
    this.el.addEventListener("phx:copy", (e) => {
      const textToCopy = this.el.textContent
      
      navigator.clipboard.writeText(textToCopy).then(() => {
        const button = document.querySelector('button[phx-click*="phx:copy"]')
        if (button) {
          const originalText = button.innerHTML
          button.innerHTML = '<svg class="w-4 h-4 mr-1" fill="currentColor" viewBox="0 0 20 20"><path fill-rule="evenodd" d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z" clip-rule="evenodd"></path></svg>Copied!'
          button.classList.add('bg-green-50', 'text-green-700', 'border-green-300')
          
          setTimeout(() => {
            button.innerHTML = originalText
            button.classList.remove('bg-green-50', 'text-green-700', 'border-green-300')
          }, 2000)
        }
      }).catch(err => {
        console.error('Failed to copy:', err)
      })
    })
  }
}

let csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
let liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: Hooks
})

topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

liveSocket.connect()

window.liveSocket = liveSocket
