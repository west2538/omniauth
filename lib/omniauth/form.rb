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

      <input type='text' value='' id='#{name}' name='#{name}'><br>
      <span class='small'>アナザーギルド(another-guild.com)の冒険者は「ユーザー名@another-guild.com」をご入力ください。例: taroというユーザー名ならば「taro@another-guild.com」となります。それ以外のMastodonインスタンスのユーザーは「ユーザー名@インスタンスのドメイン」を入力してください。</span>

      "
      # <select style='width: 100%;' class='select-box' id='#{name}' name='#{name}'>
      #   <option selected value='townsguild@another-guild.com'>@another-guild.com</option>
      # </select>

      # <input type='hidden' value='townsguild@another-guild.com' id='#{name}' name='#{name}'>
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
      @html << "<button class='square_btn' type='submit' data-disable-with='処理中..'>次へ進む</button>"
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

      </head>
      <body>

      <div class="box12">

      <div class="box26">

        <span class="box-title">ルートを探せ</span>

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
