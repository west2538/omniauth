module OmniAuth
  class Form
    DEFAULT_CSS = File.read(File.expand_path('../form.css', __FILE__))

    attr_accessor :options

    def initialize(options = {})
      options[:title] ||= 'Authentication Info Required'
      options[:header_info] ||= ''
      self.options = options

      @html = ''
      @with_custom_button = false
      @footer = nil
      header(options[:title], options[:header_info])
    end

    def self.build(options = {}, &block)
      form = OmniAuth::Form.new(options)
      if block.arity > 0
        yield form
      else
        form.instance_eval(&block)
      end
      form
    end

    def label_field(text, target)
      # @html << "\n<label for='#{target}'>#{text}:</label>"
      @html << ""
      self
    end

    def input_field(type, name)
      # @html << "<p><input style='width: 300px;' class='mb-2 form-control' type='#{type}' id='#{name}' name='#{name}' value='@another-guild.com'/></p>"
      @html << "
      <p>
      <select style='width: 100%;' class='mb-2 custom-select mr-sm-2' id='#{name}' name='#{name}'>
        <option selected value='townsguild@another-guild.com'>@another-guild.com</option>
      </select>
      </p>
      "

      # @html << "
      # <div class='form-row align-items-center mb-2'>
	    #   <input type='#{type}' name='#{name}' style='width: 105px;' class='float-left form-control'/>
	    #   <div class='input-group-prepend mr-2' style='width: 40px;'>
		  #     <div class='input-group-text'>@</div>
	    #   </div>
	    #   another-guild.com
      # </div>
      # "
      # name = "guest@another-guild.com"

      # @html << "\n<input type='#{type}' id='#{name}' name='#{name}'/>"
      self
    end

    def text_field(label, name)
      label_field(label, name)
      input_field('text', name)
      self
    end

    def password_field(label, name)
      label_field(label, name)
      input_field('password', name)
      self
    end

    def button(text)
      @with_custom_button = true
      # @html << "\n<button type='submit'>#{text}</button>"
      @html << "<p class='mt-3 text-center'><input class='btn btn-primary btn-lg' type='submit' value='次へ進む'></p>"
    end

    def html(html)
      @html << html
    end

    def fieldset(legend, options = {}, &block)
      @html << "\n<fieldset#{" style='#{options[:style]}'" if options[:style]}#{" id='#{options[:id]}'" if options[:id]}>\n  <legend>#{legend}</legend>\n"
      instance_eval(&block)
      @html << "\n</fieldset>"
      self
    end

    def header(title, header_info)
      @html << <<-HTML
      <!DOCTYPE html>
      <html>
      <head>
        <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">

        <title>#{title}</title>
        #{css}
        #{header_info}

        <script>
        $(document).on "page:change", ->
            window.prevPageYOffset = window.pageYOffset
            window.prevPageXOffset = window.pageXOffset
          $(document).on "page:load", ->
            if $(".fix-scroll").length > 0
              $('.fix-scroll').hide().show() # force re-render -- having an issue with that on Chrome/OSX
              window.scrollTo window.prevPageXOffset, window.prevPageYOffset
        </script>

      </head>
      <body>

      <!-- Bootstrap CSS -->
      <link rel="stylesheet" href="https://stackpath.bootstrapcdn.com/bootstrap/4.1.2/css/bootstrap.min.css" integrity="sha384-Smlep5jCw/wG7hdkwQ/Z5nLIefveQRIY9nfy6xoR1uRYBtpZgI6339F5dgvm/e9B" crossorigin="anonymous">

      <div class="mt-3" style="width: 320px; margin: auto;">

      <div class="jumbotron">

      <div class="container">

        <h2>ルートを探せ</h2>

        <p>『剣と魔法の時代』が終わり百数十年。平和な世界に新たな危機が迫っていた。</p>

        <p>とにもかくにも「経済成長」。お金がものをいう世界では人々は生活費を稼ぐのに必死でいつしか冒険や本当の豊かさを忘れ、ただただ消費し、心が疲れていったのである。</p>
    
        <p>それにともない冒険のよりどころの「ギルド」も姿を消していった。</p>

        <p>そんななか、人々は少しでも世の中を楽しくしようと、ギルドに行かなくてもだれでもどこでもスキマ時間に挑戦できるちょっとしたクエストを、遊びごころあふれる「サブクエスト」として発信していった。</p>

        <p>するとそんなサブクエストをクリアしていく「冒険者」たちが次々と現れはじめたのである。</p>

        <p>ここは『まちかどルート』。<br>急ぎすぎた足をいったん止め、新たなるルートを探す分岐点。</p>

        <p>“真の魔王”を倒し、そして伝説となるであろう冒険者たちと人々のルートが、いまここから始まる。</p>

        <p class="text-center">. . .</p>

        <p class="text-center">. .</p>

        <p class="text-center"></p>

        <h2>さあ！ログイン</h2>
 
        <form method='post' #{"action='#{options[:url]}' " if options[:url]}noValidate='noValidate'>
 
        HTML
      self
    end

    def footer
      return self if @footer
      @html << "\n<button type='submit'>Connect</button>" unless @with_custom_button
      @html << <<-HTML
      </form>
      </div>

      </div>

      <script src="https://code.jquery.com/jquery-3.2.1.slim.min.js" integrity="sha384-KJ3o2DKtIkvYIK3UENzmM7KCkRr/rE9/Qpg6aAZGJwFDMVNA/GpGFF93hXpG5KkN" crossorigin="anonymous"></script>
      <script src="https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.12.9/umd/popper.min.js" integrity="sha384-ApNbgh9B+Y1QKtv3Rn7W3mgPxhU9K/ScQsAP7hUibX39j7fakFPskvXusvfa0b4Q" crossorigin="anonymous"></script>
      </body>
      </html>
      HTML
      @footer = true
      self
    end

    def to_html
      footer
      @html
    end

    def to_response
      footer
      Rack::Response.new(@html, 200, 'content-type' => 'text/html').finish
    end

  protected

    def css
      "\n<style type='text/css'>#{OmniAuth.config.form_css}</style>"
    end
  end
end
