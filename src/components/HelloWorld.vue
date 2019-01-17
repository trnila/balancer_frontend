<template>
  <div class="app">
    <span v-if="connection_state" class="message">{{connection_state}}</span>
    <canvas ref="canvas" @click="canvas_clicked" v-on:touchstart="touchstart" v-on:touchend="touchend" :hidden="connection_state"></canvas>
    <div v-if="show_settings" class="settings">
      flip_x: <input type="checkbox" v-model="flip_x">
      flip_y: <input type="checkbox" v-model="flip_y">
      flip_sides: <input type="checkbox" v-model="flip_sides">
      <button @click="clicked" style="width: 80px">{{angle % 360}}</button>
      <button @click="() => this.show_settings = false">Close</button>
    </div>
  </div>
</template>

<script>
import ROSLIB from 'roslib'
import {scale, rotate, translate, transform, applyToPoint, inverse} from 'transformation-matrix'

const PERSIST_KEYS = ['angle', 'flip_x', 'flip_y', 'flip_sides']
const STATE_CONNECTING = "connecting..."
const STATE_CONNECTED = "waiting for data..."
const STATE_ERROR = "error..."
const STATE_WORKING = null;

export default {
  data() {
    return {
      width: 0,
      height: 0,
      position: [0, 0],
      dimension: [170, 230],
      boundary: [0, 0, 170, 230],
      angle: 0,
      i: 0,
      target: [-10, -10],
      flip_x: false,
      flip_y: false,
      flip_sides: false,
      margin: 40,

      touch_timer: null,
      show_settings: false,

      connection_state: STATE_CONNECTING,
      reconnect_timer: null,

      nodata_timer: null,
    }
  },

  watch: {
    show_settings() {
      requestAnimationFrame(this.redraw)
    }
  },

  mounted() {
    this.ctx = this.$refs['canvas'].getContext('2d');

    for(let key in PERSIST_KEYS) {
      key = PERSIST_KEYS[key]
      if(localStorage[key]) {
        let value = null;
        if(localStorage[key] === "true") {
          value = true;
        } else if (localStorage[key] === "false") {
          value = false;
        } else {
          value = parseInt(localStorage[key])
        }
        this.$set(this, key, value)
      }

      this.$watch(key, (value) => {
        localStorage[key] = value
        requestAnimationFrame(this.redraw)
        this.on_resize()
      })
    }

    this.init_ros();

    window.addEventListener('resize', this.on_resize)
    this.on_resize()
  },

  methods: {
    init_ros() {
      if(this.nodata_timer) {
        clearInterval(this.nodata_timer)
      }

      this.connection_state = STATE_CONNECTING
      var ros = new ROSLIB.Ros({
          url : 'ws://balancer.local:9090'
      });
      this.ros = ros

      ros.on('error', (error) => {
        this.connected = false
        this.connection_state = STATE_ERROR
        console.log(error)

        if(this.reconnect_timer) {
          clearTimeout(this.reconnect_timer)
        }
        this.reconnect_timer = setTimeout(this.init_ros, 1000);
      });

      ros.on('close', () => {
        this.connected = false
        this.connection_state = STATE_ERROR
        console.log('closed')

        if(this.reconnect_timer) {
          clearTimeout(this.reconnect_timer)
        }
        this.reconnect_timer = setTimeout(this.init_ros, 1000);
      });

      ros.on('connection', () => {
        this.connected = true
        this.connection_state = STATE_CONNECTED

        this.nodata_rearm()
        requestAnimationFrame(this.redraw)
      })

      var listener = new ROSLIB.Topic({
        ros : ros,
        name : '/measurements',
        messageType : 'ballbalancer_msgs/Measurement'
      });

      listener.subscribe((message) => {
          this.nodata_rearm()

          this.connection_state = STATE_WORKING
          this.position = [message['pos_x'], message['pos_y']]
          this.target = [message['target_x'], message['target_y']]
          window.requestAnimationFrame(this.redraw)
      });
    },

    touchstart() {
      this.touch_timer = setTimeout(() => this.show_settings = true, 2000)
    },

    touchend() {
      if(this.touch_timer) {
        clearTimeout(this.touch_timer)
      }
    },

    clicked() {
      this.angle = (this.angle + 90) % 360;
      let tmp = this.width;
      this.width = this.height;
      this.height = tmp;

      this.on_resize()
    },

    on_resize() {
      const w = window.innerWidth
      const h = window.innerHeight

      this.$refs['canvas'].width = w
      this.$refs['canvas'].height = h


      let dims;
      if(this.flip_sides) {
        dims = (this.get_quadrant() == 0 || this.get_quadrant() == 2) ? 
        [this.dimension[1], this.dimension[0]] :
        [this.dimension[0], this.dimension[1]];
      } else {
        dims = (this.get_quadrant() == 0 || this.get_quadrant() == 2) ? 
        [this.dimension[0], this.dimension[1]] :
        [this.dimension[1], this.dimension[0]];
      }

      

      
      if(w > h) {
          this.height = Math.min(h - 40, (w - 40) / (dims[0] / dims[1]))
          this.width = this.height * dims[0] / dims[1]
      } else {
          this.width = Math.min(w - 40, (h - 40) / (dims[0] / dims[1]))
          this.height = this.width * dims[0] / dims[1];
      }

      this.offset = [
        w / 2 - this.width / 2,
        h / 2 - this.height  / 2
      ]

      this.build_matrix()
    },

    canvas_clicked(event) {
        var rect = this.$refs['canvas'].getBoundingClientRect();
        
        let transformed = applyToPoint(inverse(this.matrix), {
          x: event.clientX - rect.left,
          y: event.clientY - rect.top
        });

        if(transformed.x < 0 || transformed.y < 0 || transformed.x >= this.dimension[0] || transformed.y >= this.dimension[1]) {
          return;
        }

        this.target = [transformed.x, transformed.y];

        var addTwoIntsClient = new ROSLIB.Service({
            ros : this.ros,
            name : '/SetTargetPosition',
            serviceType : 'ballbalancer_msgs/SetTargetPosition'
        });

        var request = new ROSLIB.ServiceRequest({
            x: parseInt(transformed.x),
            y: parseInt(transformed.y)
        });
        addTwoIntsClient.callService(request);
    },

    build_matrix() {
          const q = this.get_quadrant()

          let t = translate(this.offset[0], this.offset[1])
          let tx = 0;
          let ty = 0;

          if(q == 0) {
            tx = this.flip_x
            ty = this.flip_y
          } else if(q == 1) {
            ty = !this.flip_x
            tx = this.flip_y            
          } else if(q == 2) {
            tx = !this.flip_x
            ty = !this.flip_y
          } else {
            tx = !this.flip_y
            ty = this.flip_x
          }

          let sx, sy;
          if(q == 1 || q == 3) {
            sx = this.height / this.dimension[0];
            sy =  this.width / this.dimension[1];
          } else {
            sx = this.width / this.dimension[0];
            sy = this.height / this.dimension[1];
          }

          if(this.flip_y) {
            if(q == 1 || q == 3) {
              sx *= -1;
            } else {
              sy *= -1;
            }
          }

          if(this.flip_x) {
            if(q == 1 || q == 3) {
              sy *= -1;
            } else {
              sx *= -1;
            }
          }

          this.matrix = transform(
            t,
            rotate(this.angle * Math.PI/180),
            scale(sx, sy),
            translate(-tx * this.dimension[0], -ty * this.dimension[1])
          );
    },

    redraw() {
      this.build_matrix()
      let ctx = this.ctx;

      ctx.fillStyle = 'black'
      ctx.fillRect(0, 0, this.$refs['canvas'].width, this.$refs['canvas'].height)

      ctx.fillStyle = 'green'
      ctx.fillRect(this.offset[0], this.offset[1], this.width, this.height)


      let make = (p, color) => {
        let point = applyToPoint(this.matrix, {x: p[0], y: p[1]});
        
        ctx.beginPath();
        ctx.arc(point.x, point.y, 5, 0, 2 * Math.PI);
        ctx.fillStyle = color
        ctx.fill()
      }

      if(this.show_settings) {
        make([0, 0], 'blue')
        make([this.dimension[0], 0], 'red')
        make([this.dimension[0], this.dimension[1]], 'pink')
      }     

      make([this.position[0], this.position[1]], 'pink')
      make([this.target[0], this.target[1]], 'yellow')
    },

    get_quadrant() {
      return this.angle % 360 / 90
    },

    nodata_rearm() {
      if(this.nodata_timer) {
        clearInterval(this.nodata_timer)
      }

      this.nodata_timer = setInterval(() => this.connection_state = STATE_CONNECTED, 5000)
    }
  }
}
</script>

<style scoped>
div.app {
  width: 100%;
  height: 100%;
}

div.settings {
  position: absolute;
  top: 0px;
  left: 0px;
}

.message {
  display: flex;
    align-items: center;
  justify-content: center;
  font-size: 10vmin;
  z-index: 1;
  position: absolute;
  top: 0px;
  width: 100%;
  height: 100%;
}
</style>