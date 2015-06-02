define ['common/canwz_app', 'jquery', 'crafty', 'display/user_handler'], (CanwzApp, $, Crafty, UserHandler) ->

  class BloxDisplay extends CanwzApp
    timers: []
    blocksinterval: null
    initialPosition: {}

    unload: (done) ->
      super =>
        _.each this.timers, (timer) ->
          clearTimeout(timer)
        UserHandler.get().off 'user_added', this.addUser.bind(this)
        UserHandler.get().off 'user_removed', this.removeUser.bind(this)
        done()
    
    didReceiveTouchEvent: (event, done) =>
      super event, =>
        ship = this.findShipForUser(event.connection_id)
        if ship?
          switch event.action
            when 'start'
              this.initialPosition[event.connection_id] = ship.pos()
            when 'move'
              touch = event.touches[0]
              initial = this.initialPosition[event.connection_id]
              if initial?
                ship.x = Crafty.math.clamp(
                  initial._x + touch.x * 2,
                  0 - ship.pos()._w /2,
                  1920 - ship.pos()._w / 2)
            when 'end'
              delete this.initialPosition[event.connection_id]
        done()
    
    addUser: (user) ->
      this.addShipForUser(user.color, user.connection_id)
      #this.addScoreTextForUser(user.color, user.connection_id)
      #this.layoutScoreTexts()
    
    removeUser: (user) =>
      ship = this.findShipForUser(user.connection_id)
      ship.destroy() if ship?

    getWinnerColor: =>
      winner = _.min(Crafty('Ship').get(), (s) -> s._y)
      return winner._color if winner?

    findShipForUser: (connection_id) =>
      return _.find(Crafty('Ship').get(), (a) -> a.connection_id is connection_id)
    
    addShipForUser: (color, connection_id) ->
      ship = Crafty.e('Ship').attr({connection_id: connection_id, color: color })

      $(ship._element).css({'background-image' : ''})
      $.get 'img/ship.svg', (data) =>
        svg = $(data).find('svg')
        svg = svg.removeAttr('xmlns:a')
        svg.find('path').css({ fill: color }).attr('stroke', color)
        $(ship._element).append(svg)

    findScoreTextForUser: (connection_id) =>
      return _.find(Crafty('Score').get(), (h) -> h.connection_id is connection_id)

    addScoreTextForUser: (color, connection_id) =>
      Crafty.e('Score').attr({color: color, connection_id: connection_id })

    didLoad: (done) ->
      super =>
        this.app = this;
        this.setupCrafty()
        done()
    
    layoutScoreTexts: =>
      scores = Crafty('Score').get()
      for score, i in scores
        score.y = 1080 - (scores.length * 70) + i * 70
        score.x = 1920 - (scores.length * 70) + i * 70
    #c52125 Blocks
    
    setupCrafty: ->
      app = this

      Crafty.init(1920, 1080, this.element.find('#game').get(0)) #Change target this.element.find().get(0)

      Crafty.scene 'intro', ->
        logo = Crafty.e '2D, DOM, Image, Tween'
          .attr({ alpha: 0.0, x: 585, y: 165 })
          .image('img/blox-logo.png')
          .tween({ alpha: 1.0 }, 1700)
          .css('background-size', '100% 100%')
        Crafty.background('#0e476f')

        setTimeout -> 
          logo.bind 'TweenEnd', ->
            Crafty.scene 'Game'
          logo.tween({ alpha: 0.0 }, 1700)
        , 3000

      Crafty.scene 'Game', ->

        Crafty.c 'Ship', {
          init: ->
            this.requires '2D, DOM, Collision, Image, Tween, Color'
            .attr({w: 50, h: 71, x: Crafty.math.randomInt(20, 1860), y: Crafty.math.randomInt(840, 870)})
            .image('img/ship.svg')
            .onHit('HinderBlocks', ->
              if this.collidable
                this.tween({ y: 870 }, 500)
            )
            .bind('EnterFrame', ->
              if(this.y > 100)
                this.y -= 0.5
            )
            .stopOnSolids()
            .onHit('leftBorder', ->
              this.tween({ x: this.x + 25 }, 500)
            )
            .onHit('rightBorder', ->
              this.tween({ x: this.x - 25 }, 500)
            )
            .onHit('Booster', ->
              if this.y > 100
                this.y -= 3
                setTimeout ->
                  this.y -= 0.5
                , 1500

            )
            .onHit('Depresser', ->
              if this.y > 100
                this.y += 10
                setTimeout ->
                  this.y -= 0.5
                , 2000
            )
            .onHit('Shield', ->
              this.attr({ alpha: 0.4 })
              this.collidable = false
              ship = this
              setTimeout ->
                ship.collidable = true
                ship.attr({ alpha: 1.0 })
              , 7000
            )
            .collision(new Crafty.polygon([25, 0], [50, 71], [0, 71], [25, 0]))

          stopOnSolids: ->
            this.onHit('Solid', this.stopMovement)

          stopMovement: ->
            this._speed = 0
            if this._movement?
              this.x -= this._movement.x
              this.y -= this._movement.y
          collidable: true
        }

        Crafty.c 'HinderBlocks', {
          init: ->
            this.requires '2D, DOM, HitBox, Tween, Color, Image'
            .color '#c52125'
            .attr({ w: 50, h: 50 })
            .bind 'EnterFrame', ->
              if this.y > 1080
                this.destroy()
        }

        Crafty.c 'Booster', {
          init: ->
            this.requires '2D, DOM, Image, Tween'
              .image('img/booster.png')
              .attr({ w: 140, y: 100 })
              .bind 'EnterFrame', ->
                if this.y > 1080
                  this.destroy()
        }

        Crafty.c 'Depresser', {
          init: ->
            this.requires 'Booster'
            .image('img/depresser.png')
        }

        Crafty.c 'Info', {
          init: ->
            this.requires '2D, DOM, Image, Tween'
            .image('img/info.png')
            .attr({ x: 710, y: 50 })
        }

        Crafty.c 'Shield', {
          init: ->
            this.requires '2D, DOM, Image, Tween'
            .image('img/shield.png')
            .attr({ w: 70, h: 73 })
            .bind 'EnterFrame', ->
              if this.y > 1080
                this.destroy()
        }

        leftBorder = Crafty.e('leftBorder')
          .requires '2D, DOM, Color, Solid'
          .attr({x: 0, y: 0, w: 20, h: 1080})
          .color '#1771b0'
        rightBorder = Crafty.e('rightBorder')
          .requires '2D, DOM, Color, Solid'
          .attr({x: 1900, y: 0, w: 20, h: 1080})
          .color '#1771b0'

        infotext = Crafty.e('Info')

        tweenSpeed = 2700
        spawnPosition = Crafty.math.randomInt(leftBorder._w, 1920 - (rightBorder._w + 70))
        colors = [
          '#c52125'
        ]

        blocksinterval = setInterval ->
          randomColor = colors[Math.floor(Math.random() * colors.length)]

          switch Crafty.math.randomInt(1, 10)
            when 1
              #spawn a wall of blocks :O
              setTimeout(2000)
              Crafty.e('HinderBlocks')
                .attr({ w: 800, x: leftBorder._w, y: 0 - 50 })
                .color(randomColor)
                .tween({ y: 1080 + 50 }, tweenSpeed)
              Crafty.e('HinderBlocks')
                .attr({ w: 700, x: 1200, y: 0 - 50})
                .color(randomColor)
                .tween({ y: 1080 + 50 }, tweenSpeed)
            else
              for i in [0.. Crafty.math.randomInt(1, 10)]
                blocksPositionX = Crafty.math.randomInt(leftBorder._w, 1920 - (rightBorder._w + 50))

                if Crafty.math.randomInt(0, 6) == 6 then degrees = Crafty.math.randomInt(0, 90)
                else degrees = 0

                Crafty.e('HinderBlocks')
                  .attr({ x: blocksPositionX, y: 0 - 50 })
                  .color(randomColor)
                  .attr({ w: Crafty.math.randomInt(50, 100), h: Crafty.math.randomInt(50, 100), rotation: degrees })
                  .tween({ y: 1080 + 50}, 2700)
                ship.image('leading.png')
        , 1000


        itemsinterval = setInterval ->
          items = [
            #'Booster',
            #'Depresser',
            'Shield'
          ]

          if 1 == Crafty.math.randomInt(1, 10)
            Crafty.e(items[Math.floor(Math.random()*items.length)])
              .attr({ x: Crafty.math.randomInt(leftBorder._w, 1920 - (rightBorder._w + 70)), y: 0 - 70})
              .tween({ y: 1080 + 100 }, 2700)
        , 600

        a = 0.0
        t = 30.0
        totalTime = 60000.0
        startTime = Date.now()
        winner = null
        loader = document.getElementById('loader')
        $('#countdown').show()

        draw = () =>
          a = (Date.now() - startTime) / (totalTime / 360)
          r = (a * Math.PI / 180)
          x = Math.sin(r) * 125
          y = Math.cos(r) * -125
          mid = if a > 180 then 1 else 0
          anim = "M 0 0 v -125 A 125 125 1 #{mid} 1 #{x} #{y} z"
          loader.setAttribute('d', anim)

          if a <= 360.0
            setTimeout(draw, t)
        draw()

        setTimeout ->
          infotext.tween({ alpha: 0.0 }, 1000)
        , 5000

        setTimeout ->
          clearInterval(blocksinterval)
          clearInterval(itemsinterval)
          $('#countdown').hide()
          winner = app.getWinnerColor()
          Crafty.scene('Result')
        , totalTime

        Crafty.scene 'Result', ->

          winningShip = Crafty.e('2D, DOM, Image, Tween')
            .attr({ w: 150, h: 213, x: 897.5, y: 500 })
            .image('img/winnership.svg')
            .tween({ alpha: 1.0 }, 1000)

          $(winningShip._element).css({'background-image' : ''})
          $.get 'img/winnership.svg', (data) =>
            svg = $(data).find('svg')
            svg = svg.removeAttr('xmlna:a')
            svg.find('path').css({ fill: winner }).attr('stroke', winner) #.color
            $(winningShip._element).append(svg)

          logo = Crafty.e('2D, DOM, Image, Tween')
          .image('img/blox-text.png')
          .attr({ alpha: 0.0, x: 631.5, y: 170 })
          .css('background-size', '100% 100%')
          .tween({ alpha: 1.0 }, 1000)

          if winner?
            winnerText = Crafty.e('2D, DOM, Image, Tween')
                .attr({ alpha: 0.0, x: 802.5, y: 750 })
                .tween({ alpha: 1.0 }, 1000)
                .image('img/has-won.png')

          setTimeout ->
            logo.bind 'TweenEnd', ->
              app.exit
              Crafty.scene('intro')
            logo.tween({ alpha: 0.0 }, 1000)
            winnerText.tween({ alpha: 0.0 }, 1000)
            winningShip.tween({ alpha: 0.0 }, 1000)
            $('#winner').fadeOut(1000)
          , 6000

      Crafty.load(images: [
        'img/blox-logo.png',
        'img/blox-text.png',
        'img/info.png',
        'img/has-won.png'
      ], => Crafty.scene('intro'))