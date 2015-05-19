define ['common/canwz_app', 'jquery', 'crafty', 'display/user_handler'], (CanwzApp, $, Crafty, UserHandler) ->

  class BloxDisplay extends CanwzApp
    timers: []
    blocksinterval: null
    winner: []
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
              console.log initial
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
      this.addScoreTextForUser(user.color, user.connection_id)
      this.layoutScoreTexts()
    
    removeUser: (user) =>
      ship = this.findShipForUser(user.connection_id)
      ship.destroy() if ship?

      score = this.findScoreTextForUser(user.connection_id)
      score.destroy() if score?

      this.layoutScoreTexts()

    getWinnerColor: =>
      #winner = _.max(Crafty('Score').get(), (s) -> s._score)
      winner = _.min(Crafty('Ship').get(), (s) -> s._y)
      return winner._color if winner?

    findShipForUser: (connection_id) =>
      return _.find(Crafty('Ship').get(), (a) -> a.connection_id is connection_id)
    
    addShipForUser: (color, connection_id) ->
      ship = Crafty.e('Ship').attr({connection_id: connection_id })

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
      score._color = color

    didLoad: (done) ->
      super =>
        this.app = this;
        this.setupCrafty()
        done()
    
    layoutScoreTexts: =>
      scores = Crafty('Score').get()
      #for score, i in scores
        #score.y = 1080 - (scores.length * 70) + i * 70
        #score.x = 1920 - (scores.length * 70) + i * 70
    
    #0e476f Primary
    #156096 Secondary
    #c52125 Blocks
    
    setupCrafty: ->
      app = this

      Crafty.init(1920, 1080, this.element.find('#game')) #Change target

      Crafty.scene 'intro', ->
        logo = Crafty.e '2D, DOM, Image, Tween'
          .attr({ alpha: 0.0, x: 585, y: 165 })
          .image('/assets/app/blox-game/img/blox-logo.png')
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
            this.requires '2D, DOM, Collision, Image, Tween' #Twoway for testing
            .attr({w: 50, h: 71, x: Crafty.math.randomInt(20, 1860), y: 870})
            .image('/assets/app/blox-game/img/ship.svg')
            .onHit('HinderBlocks', ->
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
            .collision(new Crafty.polygon([25, 0], [50, 71], [0, 71], [25, 0]))

          stopOnSolids: ->
            this.onHit('Solid', this.stopMovement)

          stopMovement: ->
            this._speed = 0
            if this._movement?
              this.x -= this._movement.x
              this.y -= this._movement.y
        }

        Crafty.c 'HinderBlocks', {
          init: ->
            this.requires '2D, DOM, HitBox, Tween, Color'
            .color '#c52125'
            .attr({ w: 50, h: 50 })
            .bind 'EnterFrame', ->
              if this.y > window.innerHeight
                this.destroy()
        }

        Crafty.c 'Info', {
          init: ->
            this.requires '2D, DOM, Image, Tween'
            .image('/assets/app/blox-game/img/info.png')
            .attr({ x: 710, y: 50 })
        }

        Crafty.c 'Score', {
          init: ->
            this.requires('2D, DOM, Text')
            .attr({ x: 50, w: 200, h: 70 })
            .textFont({ family: 'Headline', size: '48pt' })
            .setter('score', (newScore) ->
              this._attr("_score", newScore)
            )
            this.score = 0
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

        for user in UserHandler.get().users
          app.addUser(user)

        UserHandler.get().on 'user_added', app.addUser #.bind(app)
        UserHandler.get().on 'user_removed', app.removeUser #.bind(app)

        app.blocksinterval = setInterval -> #app

            #staticGen

          side = 50

          for i in [0.. Crafty.math.randomInt(1, 10)]
            blocksPositionX = Crafty.math.randomInt(leftBorder._w, 1920 - (rightBorder._w + side))
            blocksPositionY = Crafty.math.randomInt(10, 100)

            Crafty.e('HinderBlocks')
            .attr({ x: blocksPositionX, y: 0 - side })
            .tween({ y: 1080 + 50}, 2700)
            blocksPositionX += 95
        , 1000

        a = 0.0
        t = 30.0
        totalTime = 60000.0
        startTime = Date.now()
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
          clearInterval(app.blocksinterval)
          $('#countdown').hide()
          app.winner = app.getWinnerColor()
          Crafty.scene('Result')
        , totalTime

        Crafty.scene 'Result', ->

          winningShip = Crafty.e('2D, DOM, Image, Tween')
            .attr({ w: 150, h: 213, x: 897.5, y: 500 })
            .image('/assets/app/blox-game/img/winnership.svg')
            .tween({ alpha: 1.0 }, 1000)

          $(winningShip._element).css({'background-image' : ''})
          $.get '/assets/app/blox-game/img/winnership.svg', (data) =>
            svg = $(data).find('svg')
            svg = svg.removeAttr('xmlna:a')
            svg.find('path').css({ fill: app.winner }).attr('stroke', app.winner)
            $(winningShip._element).append(svg)

          logo = Crafty.e('2D, DOM, Image, Tween')
          .image('img/blox-text.png')
          .attr({ alpha: 0.0, x: 631.5, y: 170 })
          .css('background-size', '100% 100%')
          .tween({ alpha: 1.0 }, 1000)

          if app.winner?
            winnerText = Crafty.e('2D, DOM, Image, Tween')
              .attr({ alpha: 0.0, x: 802.5, y: 750 })
              .tween({ alpha: 1.0 }, 1000)
              .image('/assets/app/blox-game/img/has-won.png')

          setTimeout ->
            logo.bind 'TweenEnd', ->
              app.exit =>
            logo.tween({ alpha: 0.0 }, 1000)
            winnerText.tween({ alpha: 0.0 }, 1000)
            winningShip.tween({ alpha: 0.0 }, 1000)
            $('#winner').fadeOut(1000)
          , 6000

      Crafty.load(images: [
        '/assets/app/blox-game/img/blox-logo.png',
        '/assets/app/blox-game/img/blox-text.png',
        '/assets/app/blox-game/img/info.png',
        '/assets/app/blox-game/img/has-won.png'
      ], => Crafty.scene('intro'))