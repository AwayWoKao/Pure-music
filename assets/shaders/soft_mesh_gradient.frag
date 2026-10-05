#include <flutter/runtime_effect.glsl>

#define S(a, b, t) smoothstep(a, b, t)

uniform vec2 uSize;
uniform float uTime;
uniform vec3 uColor1;
uniform vec3 uColor2;
uniform vec3 uColor3;
uniform vec3 uColor4;

out vec4 fragColor;

mat2 rotate2d(float angle) {
  float sine = sin(angle);
  float cosine = cos(angle);
  return mat2(cosine, -sine, sine, cosine);
}

vec2 hash2(vec2 point) {
  vec3 value = fract(vec3(point.xyx) * vec3(0.1031, 0.1030, 0.0973));
  value += dot(value, value.yzx + 33.33);
  return fract((value.xx + value.yz) * value.zy);
}

float gradientNoise(vec2 point) {
  vec2 cell = floor(point);
  vec2 local = fract(point);
  vec2 curve = local * local * (3.0 - 2.0 * local);
  float bottom = mix(
    dot(-1.0 + 2.0 * hash2(cell), local),
    dot(-1.0 + 2.0 * hash2(cell + vec2(1.0, 0.0)), local - vec2(1.0, 0.0)),
    curve.x
  );
  float top = mix(
    dot(-1.0 + 2.0 * hash2(cell + vec2(0.0, 1.0)), local - vec2(0.0, 1.0)),
    dot(-1.0 + 2.0 * hash2(cell + vec2(1.0, 1.0)), local - vec2(1.0, 1.0)),
    curve.x
  );
  return 0.5 + 0.5 * mix(bottom, top, curve.y);
}

vec2 flowField(vec2 point, float time) {
  float x = gradientNoise(point * 0.95 + vec2(time * 0.06, -time * 0.04));
  float y = gradientNoise(point * 0.82 + vec2(-time * 0.045, time * 0.055) + 17.3);
  return vec2(x - 0.5, y - 0.5);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  float ratio = uSize.x / uSize.y;
  vec2 warped = uv - 0.5;
  float degree = 0.5 + 0.5 * sin(uTime * 0.07);

  warped.y /= ratio;
  warped *= rotate2d(radians((degree - 0.5) * 220.0 + 180.0));
  warped.y *= ratio;

  float speed = uTime * 0.42;
  warped.x += sin(warped.y * 2.4 + speed) / 36.0;
  warped.y += sin(warped.x * 3.2 + speed) / 22.0;
  warped.x += sin(warped.y * 1.8 - speed * 0.55) / 48.0;
  warped.y += cos(warped.x * 2.6 + speed * 0.38) / 32.0;

  vec2 flow = flowField(warped * 1.25, uTime * 0.14);
  warped += flow * 0.09;
  warped += vec2(-flow.y, flow.x) * 0.04;

  float horizontalBlend = S(-0.3, 0.2, dot(warped, vec2(0.9961947, 0.0871557)));
  vec3 upper = mix(uColor1, uColor2, horizontalBlend);
  vec3 lower = mix(uColor3, uColor4, horizontalBlend);
  vec3 color = mix(upper, lower, S(0.5, -0.3, warped.y));
  fragColor = vec4(color, 1.0);
}
