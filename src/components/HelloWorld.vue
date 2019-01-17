<template>
  <div>
    <canvas ref="canvas" @click="canvas_clicked"></canvas>
    <div>
      flip_x: <input type="checkbox" v-model="flip_x">
      flip_y: <input type="checkbox" v-model="flip_y">
      <button @click="clicked" style="width: 80px">{{angle % 360}}</button>
    </div>
  </div>
</template>

<script>
import ROSLIB from 'roslib'
let {scale, rotate, translate, transform, applyToPoint, inverse} = window.TransformationMatrix;

let offset = [300, 300]

export default {
  name: 'HelloWorld',
  props: {
    msg: String
  },

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
      flip_y: false
    }
  },

  mounted() {
    this.ctx = this.$refs['canvas'].getContext('2d');

    var ros = new ROSLIB.Ros({
        url : 'ws://balancer.local:9090'
    });
    this.ros = ros

    var listener = new ROSLIB.Topic({
      ros : ros,
      name : '/measurements',
      messageType : 'ballbalancer_msgs/Measurement'
    });

    listener.subscribe((message) => {
        this.position = [message['pos_x'], message['pos_y']]
        this.target = [message['target_x'], message['target_y']]
        window.requestAnimationFrame = this.redraw
    });

    window.addEventListener('resize', this.on_resize)
    this.on_resize()

    setInterval(this.redraw, 100)
  },

  methods: {
    clicked() {
      this.angle += 90;
      let tmp = this.width;
      this.width = this.height;
      this.height = tmp;

      this.build_matrix()
    },

    on_resize() {
      this.$refs['canvas'].width = window.innerWidth;
      this.$refs['canvas'].height = window.innerHeight;

      this.height = 300;
      this.width = 200;

      /*if(w > h) {
          this.width = (h - 40) * this.dimension[1] / this.dimension[0]
          this.height = h - 40;
      } else {
          this.width = w - 40;
          this.height = (w - 40) * this.dimension[0] / this.dimension[1];
      }*/

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
            x: transformed.x,
            y: transformed.y
        });
        addTwoIntsClient.callService(request);
    },

    build_matrix() {
          const q = this.angle % 360 / 90

          let t = translate(offset[0], offset[1])
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

          /*if(this.angle % 360 == 0) {
            if(this.flip_x) {
              tx = -this.dimension[0];
            }
            if(this.flip_y) {
              ty = -this.dimension[1]
            }

          } else if (this.angle % 360 == 90) { 
            ty = -this.dimension[1]
            if(this.flip_x) {
              tx = -this.dimension[0]
            }

            if(this.flip_y) {
              ty = 0;
            }
          } else if (this.angle % 360 == 180) {
            if(!this.flip_x) {
              tx = -this.dimension[0]
              ty = -this.dimension[1]
            } else {
              ty = -this.dimension[1]
            }
           
          } else if (this.angle % 360 == 270) {
            if(!this.flip_x) {
              tx = -this.dimension[0]
            }
          } */

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
        ctx.fillRect(offset[0], offset[1], this.width, this.height)


        let make = (p, color) => {
          let point = applyToPoint(this.matrix, {x: p[0], y: p[1]});
          
          ctx.beginPath();
          ctx.arc(point.x, point.y, 5, 0, 2 * Math.PI);
          ctx.fillStyle = color
          ctx.fill()
        }

        make([0, 0], 'blue')
        make([this.dimension[0], 0], 'red')
        make([this.dimension[0], this.dimension[1]], 'pink')

        make([this.target[0], this.target[1]], 'yellow')

    }
  }
}
</script>

<style scoped>
div {
  position: absolute;
  top: 0px;
  left: 0px;
  background: red;
}
</style>