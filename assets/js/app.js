import "phoenix_html"
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import topbar from "../vendor/topbar"

let Hooks = {}

Hooks.Flash = {
  mounted() {
    this.timer = setTimeout(() => {
      this.el.dispatchEvent(new Event('click', { bubbles: true }))
    }, 5000)
  },
  destroyed() {
    if (this.timer) {
      clearTimeout(this.timer)
    }
  }
}

Hooks.HighlightCode = {
  mounted() {
    this.highlight()
  },
  updated() {
    this.highlight()
  },
  highlight() {
    if (typeof hljs !== 'undefined') {
      const codeBlock = this.el.querySelector('code')
      if (codeBlock && !codeBlock.classList.contains('hljs')) {
        hljs.highlightElement(codeBlock)
      }
    }
  }
}

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

function showModal(id) {
  const modal = document.getElementById(id)
  const bg = document.getElementById(`${id}-bg`)
  const container = document.getElementById(`${id}-container`)
  
  if (modal && bg && container) {
    modal.classList.remove('hidden')
    modal.style.display = 'block'
    
    bg.style.opacity = '0'
    bg.style.display = 'block'
    setTimeout(() => {
      bg.style.transition = 'all 0.3s ease-out'
      bg.style.opacity = '1'
    }, 10)
    
    container.classList.remove('hidden')
    container.style.opacity = '0'
    container.style.transform = 'translateY(1rem) scale(0.95)'
    container.style.display = 'block'
    setTimeout(() => {
      container.style.transition = 'all 0.3s ease-out'
      container.style.opacity = '1'
      container.style.transform = 'translateY(0) scale(1)'
    }, 10)
    
    document.body.classList.add('overflow-hidden')
  }
}

function hideModal(id) {
  const modal = document.getElementById(id)
  const bg = document.getElementById(`${id}-bg`)
  const container = document.getElementById(`${id}-container`)
  
  if (modal && bg && container) {
    bg.style.transition = 'all 0.2s ease-in'
    bg.style.opacity = '0'
    
    container.style.transition = 'all 0.2s ease-in'
    container.style.opacity = '0'
    container.style.transform = 'translateY(1rem) scale(0.95)'
    
    setTimeout(() => {
      bg.style.display = 'none'
      container.style.display = 'none'
      modal.classList.add('hidden')
      modal.style.display = 'none'
      document.body.classList.remove('overflow-hidden')
    }, 200)
  }
}

function initializeLiveView() {
  const csrfTokenElement = document.querySelector("meta[name='csrf-token']")
  
  if (!csrfTokenElement) {
    console.error('CSRF token meta tag not found')
    return
  }
  
  const csrfToken = csrfTokenElement.getAttribute("content")
  const liveSocket = new LiveSocket("/live", Socket, {
    longPollFallbackMs: 2500,
    params: {_csrf_token: csrfToken},
    hooks: Hooks
  })

  topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
  window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
  window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

  window.addEventListener("phx:copy-to-clipboard", (e) => {
    const text = e.detail.text
    navigator.clipboard.writeText(text).then(() => {
      console.log('Copied to clipboard')
    }).catch(err => {
      console.error('Failed to copy:', err)
    })
  })

  window.addEventListener("phx:download-csv", (e) => {
    const csv = e.detail.csv
    const filename = e.detail.filename || 'data.csv'
    
    const blob = new Blob([csv], { type: 'text/csv;charset=utf-8;' })
    const link = document.createElement('a')
    const url = URL.createObjectURL(blob)
    
    link.setAttribute('href', url)
    link.setAttribute('download', filename)
    link.style.visibility = 'hidden'
    
    document.body.appendChild(link)
    link.click()
    document.body.removeChild(link)
    
    URL.revokeObjectURL(url)
  })

  window.addEventListener("phx:show-modal", (e) => {
    console.log('Received show-modal event:', e.detail)
    showModal(e.detail.id)
  })

  window.addEventListener("phx:hide-modal", (e) => {
    console.log('Received hide-modal event:', e.detail)
    hideModal(e.detail.id)
  })

  liveSocket.connect()
  window.liveSocket = liveSocket
  
  console.log('LiveView initialized and connected')
  
  if (typeof hljs !== 'undefined') {
    setTimeout(() => {
      document.querySelectorAll('pre code.language-elixir').forEach((block) => {
        hljs.highlightElement(block)
      })
    }, 100)
    
    window.addEventListener('phx:page-loading-stop', () => {
      setTimeout(() => {
        document.querySelectorAll('pre code.language-elixir:not(.hljs)').forEach((block) => {
          hljs.highlightElement(block)
        })
      }, 100)
    })
  }
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initializeLiveView)
} else {
  initializeLiveView()
}
