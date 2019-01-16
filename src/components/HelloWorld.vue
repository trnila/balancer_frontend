<template>
  <div class="hello">
    <canvas ref="canvas" :width="width" :height="height" @click="canvas_clicked"></canvas>
  </div>
</template>

<script>
import ROSLIB from 'roslib'

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
    on_resize() {
      const w = window.innerWidth
      const h = window.innerHeight

      if(w > h) {
          this.width = (h - 40) * this.dimension[1] / this.dimension[0]
          this.height = h - 40;
      } else {
          this.width = w - 40;
          this.height = (w - 40) * this.dimension[0] / this.dimension[1];
      }
    },

    canvas_clicked(event) {
        var rect = this.$refs['canvas'].getBoundingClientRect();
        var y = this.dimension[1] - parseInt((event.clientX - rect.left) / this.width * this.dimension[1]);
        var x = this.dimension[0] - parseInt((event.clientY - rect.top) / this.height * this.dimension[0]);

        var addTwoIntsClient = new ROSLIB.Service({
            ros : this.ros,
            name : '/SetTargetPosition',
            serviceType : 'ballbalancer_msgs/SetTargetPosition'
        });

        var request = new ROSLIB.ServiceRequest({
            x: x,
            y: y
        });

        addTwoIntsClient.callService(request);
    },

    redraw() {
      let ctx = this.ctx;
        ctx.fillStyle = '#d03c4a'
        ctx.fillRect(0, 0, this.width, this.height)

        ctx.fillStyle = '#83D671'
        ctx.fillRect(this.boundary[0], this.boundary[1], this.width - 2 * this.boundary[0], this.height - 2 * this.boundary[1])

        let recalculate = (p) => {
            return [
              (this.dimension[1] - p[1]) / this.dimension[1] * this.width,
              (this.dimension[0] - p[0]) / this.dimension[0] * this.height,
            ]
        }

        if(this.position && this.target) {
          let point = recalculate(this.position)
          ctx.beginPath();
          ctx.arc(point[0], point[1], 5, 0, 2 * Math.PI);
          ctx.fillStyle = 'black'
          ctx.fill()

          point = recalculate(this.target)
          ctx.beginPath();
          ctx.strokeStyle = 'black'
          ctx.arc(point[0], point[1], 5, 0, 2 * Math.PI);
          ctx.stroke();
        }
    }
  }
}
</script>
