<script setup>
import DefaultTheme from 'vitepress/theme'
import { onMounted, onUnmounted, watch, ref } from 'vue'
import { useRoute, useData, withBase } from 'vitepress'

const { Layout } = DefaultTheme
const route = useRoute()
const { frontmatter } = useData()
const logoUrl = withBase('/logo.webp')
const loading = ref(true)

const bound = new WeakSet()
const follow = new WeakMap()
const tilts = new WeakMap()
let mo
let io
let raf = 0

const preview = ref(null)
const previewAlt = ref('')
const previewList = ref([])
const previewIndex = ref(0)

function prefersReduced() {
  return window.matchMedia('(prefers-reduced-motion: reduce)').matches
}

function needsTick(s) {
  return (
    Math.abs(s.tx - s.x) > 0.4 ||
    Math.abs(s.ty - s.y) > 0.4 ||
    Math.abs(s.trx - s.rx) > 0.02 ||
    Math.abs(s.ryT - s.ry) > 0.02
  )
}

function tickFollow() {
  raf = 0
  document.querySelectorAll('.pm-hot').forEach((el) => {
    const s = follow.get(el)
    if (!s) return
    s.x += (s.tx - s.x) * 0.18
    s.y += (s.ty - s.y) * 0.18
    el.style.setProperty('--mx', `${s.x}px`)
    el.style.setProperty('--my', `${s.y}px`)
    if (Math.abs(s.tx - s.x) > 0.4 || Math.abs(s.ty - s.y) > 0.4) {
      if (!raf) raf = requestAnimationFrame(tickFollow)
    }
  })
  document.querySelectorAll('.pm-card-shot').forEach((el) => {
    const s = tilts.get(el)
    if (!s) return
    s.rx += (s.trx - s.rx) * 0.12
    s.ry += (s.ryT - s.ry) * 0.12
    s.x += (s.tx - s.x) * 0.16
    s.y += (s.ty - s.y) * 0.16
    el.style.setProperty('--rx-mouse', `${s.rx.toFixed(3)}deg`)
    el.style.setProperty('--ry-mouse', `${s.ry.toFixed(3)}deg`)
    el.style.setProperty('--mx', `${s.x.toFixed(1)}px`)
    el.style.setProperty('--my', `${s.y.toFixed(1)}px`)
    if (needsTick(s) && !raf) raf = requestAnimationFrame(tickFollow)
  })
}

function onMove(e) {
  const el = e.currentTarget
  const r = el.getBoundingClientRect()
  const tx = e.clientX - r.left
  const ty = e.clientY - r.top
  let s = follow.get(el)
  if (!s) {
    s = { x: tx, y: ty, tx, ty }
    follow.set(el, s)
  }
  s.tx = tx
  s.ty = ty
  if (!raf) raf = requestAnimationFrame(tickFollow)
}

function onEnter(e) {
  e.currentTarget.classList.add('pm-hot')
}

function onLeave(e) {
  e.currentTarget.classList.remove('pm-hot')
  e.currentTarget.style.removeProperty('--mx')
  e.currentTarget.style.removeProperty('--my')
}

function onTiltMove(e) {
  if (prefersReduced()) return
  if (!window.matchMedia('(hover: hover) and (pointer: fine)').matches) return
  const el = e.currentTarget
  const r = el.getBoundingClientRect()
  const px = (e.clientX - r.left) / r.width - 0.5
  const py = (e.clientY - r.top) / r.height - 0.5
  let s = tilts.get(el)
  if (!s) {
    s = { x: r.width / 2, y: r.height / 2, tx: 0, ty: 0, rx: 0, ry: 0, trx: 0, ryT: 0 }
    tilts.set(el, s)
  }
  s.trx = -py * 9
  s.ryT = px * 12
  s.tx = e.clientX - r.left
  s.ty = e.clientY - r.top
  el.classList.add('is-tilting')
  if (!raf) raf = requestAnimationFrame(tickFollow)
}

function onTiltLeave(e) {
  const el = e.currentTarget
  const s = tilts.get(el)
  if (s) {
    s.trx = 0
    s.ryT = 0
  }
  el.classList.remove('is-tilting')
  if (!raf) raf = requestAnimationFrame(tickFollow)
}

function bindPointer() {
  const nodes = document.querySelectorAll(
    'a.VPFeature, .VPFeature.link, .download-btn, .VPButton, .VPDoc .pager-link',
  )
  nodes.forEach((el) => {
    if (bound.has(el)) return
    bound.add(el)
    el.addEventListener('pointerenter', onEnter)
    el.addEventListener('pointermove', onMove)
    el.addEventListener('pointerleave', onLeave)
  })
}

function bindTilt() {
  document.querySelectorAll('.pm-card-shot').forEach((el) => {
    if (bound.has(el)) return
    bound.add(el)
    el.addEventListener('pointermove', onTiltMove)
    el.addEventListener('pointerleave', onTiltLeave)
  })
}

function untiltFrames() {
  if (CSS.supports('animation-timeline', 'view()')) return
  const vh = window.innerHeight
  document.querySelectorAll('.pm-card-shot').forEach((el) => {
    const r = el.getBoundingClientRect()
    const start = vh
    const end = vh * 0.35
    let t = (start - r.top) / (start - end)
    t = Math.max(0, Math.min(1, t))
    el.style.setProperty('--rx-scroll', `${((1 - t) * 42).toFixed(2)}deg`)
    el.style.setProperty('--s-scroll', (0.9 + t * 0.1).toFixed(4))
  })
}

function bindScroll() {
  io?.disconnect()
  window.removeEventListener('scroll', untiltFrames)
  if (!prefersReduced()) {
    untiltFrames()
    window.addEventListener('scroll', untiltFrames, { passive: true })
  }
  io = new IntersectionObserver(
    (entries) => {
      entries.forEach((en) => {
        if (!en.isIntersecting) return
        en.target.classList.add('is-in')
        io.unobserve(en.target)
      })
    },
    { threshold: 0.2, rootMargin: '0px 0px -12% 0px' },
  )
  document.querySelectorAll('.pm-stage, .pm-close, .pm-foot').forEach((el) => {
    const rect = el.getBoundingClientRect()
    const seen = rect.top < window.innerHeight * 0.86 && rect.bottom > 48
    if (seen) {
      requestAnimationFrame(() => requestAnimationFrame(() => el.classList.add('is-in')))
    } else {
      io.observe(el)
    }
  })
}

function collectPreviewImages() {
  return [...document.querySelectorAll('.pm-card-shot img')].filter(
    (img) => img.getAttribute('src'),
  )
}

function openPreview(img) {
  const list = collectPreviewImages()
  const i = list.indexOf(img)
  previewList.value = list.map((el) => ({
    src: el.currentSrc || el.src,
    alt: el.alt || '',
  }))
  previewIndex.value = i < 0 ? 0 : i
  const cur = previewList.value[previewIndex.value]
  preview.value = cur.src
  previewAlt.value = cur.alt
  document.body.style.overflow = 'hidden'
}

function closePreview() {
  preview.value = null
  document.body.style.overflow = ''
}

function stepPreview(dir) {
  const n = previewList.value.length
  if (!n) return
  previewIndex.value = (previewIndex.value + dir + n) % n
  const cur = previewList.value[previewIndex.value]
  preview.value = cur.src
  previewAlt.value = cur.alt
}

function onDocClick(e) {
  const img = e.target.closest?.('.pm-card-shot img')
  if (!img) return
  e.preventDefault()
  openPreview(img)
}

function onKey(e) {
  if (preview.value) {
    if (e.key === 'Escape') closePreview()
    if (e.key === 'ArrowRight') stepPreview(1)
    if (e.key === 'ArrowLeft') stepPreview(-1)
    return
  }
  if ((e.key === 'Enter' || e.key === ' ') && e.target?.classList?.contains('pm-preview')) {
    e.preventDefault()
    openPreview(e.target)
  }
}

let scrollCur = 0
let scrollTarget = 0
let scrollTick = 0

function onWheelSmooth(e) {
  if (prefersReduced() || preview.value) return
  if (frontmatter.value.layout !== 'home') return
  if (e.ctrlKey) return
  e.preventDefault()
  const max = Math.max(0, document.documentElement.scrollHeight - innerHeight)
  scrollTarget = Math.max(0, Math.min(max, scrollTarget + e.deltaY))
  if (!scrollTick) scrollTick = requestAnimationFrame(stepSmooth)
}

function stepSmooth() {
  scrollCur += (scrollTarget - scrollCur) * 0.16
  if (Math.abs(scrollTarget - scrollCur) < 0.4) {
    scrollCur = scrollTarget
    scrollTick = 0
  } else {
    scrollTick = requestAnimationFrame(stepSmooth)
  }
  window.scrollTo(0, scrollCur)
  document.documentElement.style.setProperty('--pm-page-y', scrollCur.toFixed(1))
  syncNavChrome()
}

function onNativeScroll() {
  if (scrollTick) return
  scrollCur = window.scrollY
  scrollTarget = window.scrollY
  document.documentElement.style.setProperty('--pm-page-y', String(window.scrollY))
  syncNavChrome()
}

function syncNavChrome() {
  const onHome = frontmatter.value.layout === 'home'
  const narrow = window.matchMedia('(max-width: 959.98px)').matches
  const compact = narrow || !onHome || window.scrollY >= 96
  document.documentElement.classList.toggle('pm-nav-compact', compact)
}

function refresh() {
  bindPointer()
  bindTilt()
  bindScroll()
  syncNavChrome()
  collectPreviewImages().forEach((img) => {
    img.classList.add('pm-preview')
    img.setAttribute('tabindex', '0')
    img.setAttribute('role', 'button')
  })
}

onMounted(() => {
  refresh()
  document.addEventListener('click', onDocClick)
  document.addEventListener('keydown', onKey)
  window.addEventListener('scroll', onNativeScroll, { passive: true })
  window.addEventListener('wheel', onWheelSmooth, { passive: false })
  window.addEventListener('resize', syncNavChrome)
  scrollCur = window.scrollY
  scrollTarget = window.scrollY
  syncNavChrome()
  window.setTimeout(() => { loading.value = false }, 640)
  let moT
  mo = new MutationObserver(() => {
    clearTimeout(moT)
    moT = setTimeout(refresh, 40)
  })
  mo.observe(document.getElementById('app') || document.body, {
    childList: true,
    subtree: true,
  })
})

watch(
  () => route.path,
  () => {
    closePreview()
    scrollCur = 0
    scrollTarget = 0
    requestAnimationFrame(refresh)
  },
)

onUnmounted(() => {
  mo?.disconnect()
  io?.disconnect()
  window.removeEventListener('scroll', untiltFrames)
  if (raf) cancelAnimationFrame(raf)
  document.removeEventListener('click', onDocClick)
  document.removeEventListener('keydown', onKey)
  window.removeEventListener('scroll', onNativeScroll)
  window.removeEventListener('wheel', onWheelSmooth)
  window.removeEventListener('resize', syncNavChrome)
  if (scrollTick) cancelAnimationFrame(scrollTick)
  document.body.style.overflow = ''
})
</script>

<template>
  <Layout />
  <div class="pm-loader" :class="{ out: !loading }" aria-hidden="true">
    <img :src="logoUrl" width="72" height="72" alt="" />
  </div>
  <footer class="pm-foot">
    <p class="pm-foot-note">以 GPL-3.0 许可发布 · © 2026 · Made by qingyueyin</p>
  </footer>
  <Teleport to="body">
    <div
      v-if="preview"
      class="pm-lightbox"
      role="dialog"
      aria-modal="true"
      aria-label="图片预览"
      @click.self="closePreview"
    >
      <button class="pm-lightbox-close" type="button" aria-label="关闭预览" @click="closePreview">
        关闭
      </button>
      <button
        v-if="previewList.length > 1"
        class="pm-lightbox-nav prev"
        type="button"
        aria-label="上一张"
        @click="stepPreview(-1)"
      >
        上一张
      </button>
      <img :src="preview" :alt="previewAlt" class="pm-lightbox-img" />
      <button
        v-if="previewList.length > 1"
        class="pm-lightbox-nav next"
        type="button"
        aria-label="下一张"
        @click="stepPreview(1)"
      >
        下一张
      </button>
    </div>
  </Teleport>
</template>
