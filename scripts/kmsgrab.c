#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <sys/mman.h>
#include <xf86drm.h>
#include <xf86drmMode.h>

int main(int argc, char **argv)
{
    const char *out = argc > 1 ? argv[1] : "/tmp/kms.raw";
    int fd = open("/dev/dri/card0", O_RDWR);
    if (fd < 0) { perror("open card0"); return 1; }

    drmModeRes *res = drmModeGetResources(fd);
    if (!res) { fprintf(stderr, "GetResources: %s\n", strerror(errno)); return 2; }

    uint32_t fb_id = 0;
    for (int i = 0; i < res->count_crtcs; i++) {
        drmModeCrtc *c = drmModeGetCrtc(fd, res->crtcs[i]);
        if (!c) continue;
        fprintf(stderr, "crtc %u: fb=%u mode_valid=%u\n", c->crtc_id, c->buffer_id, c->mode_valid);
        if (c->mode_valid && c->buffer_id) fb_id = c->buffer_id;
        drmModeFreeCrtc(c);
    }
    if (!fb_id) { fprintf(stderr, "no active fb\n"); return 3; }

    drmModeFB2 *fb = drmModeGetFB2(fd, fb_id);
    if (!fb) { fprintf(stderr, "GetFB2(%u): %s\n", fb_id, strerror(errno)); return 4; }

    fprintf(stderr, "fb: %ux%u fmt=%.4s pitch0=%u handles0=%u\n",
            fb->width, fb->height, (char *)&fb->pixel_format,
            fb->pitches[0], fb->handles[0]);

    int prime_fd = -1;
    if (drmPrimeHandleToFD(fd, fb->handles[0], O_RDONLY, &prime_fd) < 0) {
        fprintf(stderr, "PrimeHandleToFD: %s\n", strerror(errno));
        return 5;
    }

    size_t size = (size_t)fb->pitches[0] * fb->height;
    void *map = mmap(NULL, size, PROT_READ, MAP_SHARED, prime_fd, 0);
    if (map == MAP_FAILED) { perror("mmap"); return 6; }

    FILE *f = fopen(out, "wb");
    if (!f) { perror("fopen"); return 7; }
    fwrite(map, 1, size, f);
    fclose(f);

    printf("%u %u %u\n", fb->width, fb->height, fb->pitches[0]);
    drmModeFreeFB2(fb);
    drmModeFreeResources(res);
    close(fd);
    return 0;
}
