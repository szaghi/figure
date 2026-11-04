<script setup lang="ts">
// A recording of a real FIGURE program (scripts/docs_media.py writes docs/public/media/<name>.png and .mp4):
// the video loops silently with the PNG as its poster; a still when there is no video. With reduced motion the
// video does not play by itself: it shows the poster and the controls.
import { onMounted, ref } from 'vue'
import { withBase } from 'vitepress'

const props = defineProps<{ name: string; alt: string; caption?: string; video?: boolean; width?: number }>()
const still = withBase(`/media/${props.name}.png`)
const clip = withBase(`/media/${props.name}.mp4`)
const el = ref<HTMLVideoElement | null>(null)
const reduced = ref(false)

onMounted(() => {
  reduced.value = window.matchMedia('(prefers-reduced-motion: reduce)').matches
  if (el.value && !reduced.value) el.value.play().catch(() => { reduced.value = true })
})
</script>

<template>
  <figure class="fig-media" :style="width ? { maxWidth: width + 'px' } : undefined">
    <video v-if="video" ref="el" :src="clip" :poster="still" :aria-label="alt" muted loop playsinline
           preload="metadata" :controls="reduced" />
    <img v-else :src="still" :alt="alt" loading="lazy" />
    <figcaption v-if="caption">{{ caption }}</figcaption>
  </figure>
</template>
