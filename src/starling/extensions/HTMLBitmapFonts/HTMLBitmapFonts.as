package starling.extensions.HTMLBitmapFonts
{
	import starling.display.Image;
	import starling.display.QuadBatch;
	import starling.text.BitmapChar;
	import starling.textures.Texture;
	import starling.utils.HAlign;
	
	/** 
	 * This class is used by HTMLTextField
	 * <br/><br/>
	 * XML's used by <code>add</code> and <code>addMultipleSizes</code>
	 * can be generated by <a href="http://kvazars.com/littera/">Littera</a> ou 
	 * <a href="http://www.angelcode.com/products/bmfont/">AngelCode - Bitmap Font Generator</a>
	 * <br/><br/>
	 * See an XML sample:
	 *
	 * <listing>
	 &lt;font&gt;
	 &lt;info face="BranchingMouse" size="40" /&gt;
	 &lt;common lineHeight="40" /&gt;
	 &lt;pages&gt; &lt;!-- currently, only one page is supported --&gt;
	 &lt;page id="0" file="texture.png" /&gt;
	 &lt;/pages&gt;
	 &lt;chars&gt;
	 &lt;char id="32" x="60" y="29" width="1" height="1" xoffset="0" yoffset="27" xadvance="8" /&gt;
	 &lt;char id="33" x="155" y="144" width="9" height="21" xoffset="0" yoffset="6" xadvance="9" /&gt;
	 &lt;/chars&gt;
	 &lt;kernings&gt; &lt;!-- Kerning is optional --&gt;
	 &lt;kerning first="83" second="83" amount="-4"/&gt;
	 &lt;/kernings&gt;
	 &lt;/font&gt;
	 * </listing>
	 * 
	 * Personnaly i use AssetManager for loading fonts and i just modified it like this: <br/>
	 * in loadQueue -> processXML :</br>
	 * <listing>
	 * 
	 else if( rootNode == "font" )
	 {
	 name 	= xml.info.&#64;face.toString();
	 fileName 	= getName(xml.pages.page.&#64;file.toString());
	 isBold 	= xml.info.&#64;bold == 1;
	 isItalic 	= xml.info.&#64;italic == 1;
	 
	 log("Adding html bitmap font '" + name + "'" + " _bold: " + isBold + " _italic: " + isItalic );
	 
	 fontTexture = getTexture( fileName );
	 HTMLTextField.registerBitmapFont( fontTexture, xml, xml.info.&#64;size, isBold, isItalic, name.toLowerCase() );
	 removeTexture( fileName, false );
	 
	 mLoadedHTMLFonts.push( name.toLowerCase() );
	 }
	 * </listing>
	 */ 
	public class HTMLBitmapFonts
	{
		// -- you can register emotes here --//
		
		private static var _emotesTxt				:Vector.<String>;
		private static var _emotesTextures			:Vector.<BitmapChar>;
		/** 
		 * Register emote shortcut and the texture associated 
		 * @param shortcut the shortcut of the emote
		 * @param texture the texture associated with ths emote
		 * @param xOffset a custom xOffset for the emote (default 0)
		 * @param yOffset a custom yOffset for the emote (default 0)
		 * @param xAdvance a custom xAdvance for the emote, if -1 advance will be texture.width (default -1)
		 **/
		public static function registerEmote( shortcut:String, texture:Texture, xOffset:int = 0, yOffset:int = 0, xAdvance:int = -1, margins:int = 5 ):void
		{
			if( !_emotesTxt )
			{
				_emotesTxt 		= new Vector.<String>();
				_emotesTextures = new Vector.<BitmapChar>();
			}
			
			if( xAdvance == -1 )	xAdvance = texture.width;
			var id:int = _emotesTxt.indexOf( shortcut );
			if( id == -1 )
			{
				_emotesTxt.push( shortcut );
				_emotesTextures.push( new BitmapChar(int.MAX_VALUE, texture, xOffset+margins, yOffset, xAdvance+margins*2) );
			}
			else
			{
				_emotesTxt[id] 		= shortcut;
				_emotesTextures[id] = new BitmapChar(int.MAX_VALUE, texture, xOffset+margins, yOffset, xAdvance+margins*2);
			}
		}
		
		/** space char **/
		private static const CHAR_SPACE				:int = 32;
		/** tab char **/
		private static const CHAR_TAB				:int =  9;
		/** new line char **/
		private static const CHAR_NEWLINE			:int = 10;
		/** cariage return char **/
		private static const CHAR_CARRIAGE_RETURN	:int = 13;
		/** char slash (for urls) **/
		private static const CHAR_SLASH				:int = 47;
		
		/** the base style for the font: the first added style **/
		private var _baseStyle						:int = -1;
		/** the base size for the font: the fisrt size added **/
		private var _baseSize						:int = -1;
		
		/** the font styles **/
		private var mFontStyles						:Vector.<BitmapFontStyle>;
		/** font name **/
		private var mName							:String;
		/** an helper image to construct the textField **/
		private var mHelperImage					:Image;
		
		/** the vector used for the lines **/
		private static var lines					:Vector.< Vector.<CharLocation> >;
		/** the vector for the line sizes **/
		private static var linesSizes				:Vector.<Number>;
		/** the vector for the baselines **/
		private static var baselines				:Vector.<Number>;
		
		/** the underline texture **/
		private static var _underlineTexture		:Texture;
		/** define the texture to use for underlines **/
		public static function set underlineTexture(value:Texture):void
		{
			_underlineTexture = value;
		}
		
		/** 
		 * Create a HTMLBitmapFont for a font familly
		 * @param name the name to register for this font.
		 **/
		public function HTMLBitmapFonts( name:String )
		{
			// créer la pool en statique si elle n'existe pas encore
			if( !lines )				lines 				= new <Vector.<CharLocation>>[];
			if( !linesSizes )			linesSizes			= new <Number>[];
			if( !baselines )			baselines			= new <Number>[];
			
			// définir le nom de la font
			mName 				= name;
			// créer le tableau contenant les style de fonts
			mFontStyles 		= new Vector.<BitmapFontStyle>( BitmapFontStyle.NUM_STYLES, true );
		}
		
		/** define the base size for the font **/
		public function set baseSize( value:Number ):void
		{
			_baseSize = value;
		}
		
		/** 
		 * define the base style for the font, this style must be valid and exists
		 * @see starling.extensions.HTMLBitmapFonts.BitmapFontStyle
		 * @see starling.extensions.HTMLBitmapFonts.BitmapFontStyle#REGULAR
		 * @see starling.extensions.HTMLBitmapFonts.BitmapFontStyle#BOLD
		 * @see starling.extensions.HTMLBitmapFonts.BitmapFontStyle#ITALIC
		 * @see starling.extensions.HTMLBitmapFonts.BitmapFontStyle#BOLD_ITALIC
		 **/
		public function set baseStyle( value:int ):void
		{
			if( value < BitmapFontStyle.NUM_STYLES && mFontStyles[value] != null )	_baseStyle = value;
		}
		
		/** 
		 * add multiple font sizes for this font
		 * @param textures the texture vector, one texture by font size
		 * @param fontsXML the xml vector, one xml by font size
		 * @param sizes the sizes vector, one size by font size, if null 
		 * @param bold point out if is a bold font
		 * @param italic point out if it is italic texture
		 **/
		public function addMultipleSizes( textures:Vector.<Texture>, fontsXml:Vector.<XML>, sizes:Vector.<Number>, bold:Boolean = false, italic:Boolean = false ):void
		{
			// récuperer l'index du style actuel
			var index:int = BitmapFontStyle.REGULAR;
			if( bold && italic ) 	index = BitmapFontStyle.BOLD_ITALIC;	
			else if( bold )			index = BitmapFontStyle.BOLD;
			else if( italic )		index = BitmapFontStyle.ITALIC;
			
			// créer le BitmapFontStyle pour le style si il n'existe pas encore
			if( !mFontStyles[index] )	mFontStyles[index] = new BitmapFontStyle( index, textures, fontsXml, sizes );
				// ajouter les tailles de font au BitmapFontStyle
			else						mFontStyles[index].addMultipleSizes( textures, fontsXml, sizes );
			
			// si le helperImage n'existe pas encore on le crée
			if( !mHelperImage )			mHelperImage 	= new Image( textures[0] );
			// si eucune taille de base n'est définie on prend la premiere du tableau
			if( _baseSize == -1 )		_baseSize 		= sizes[0];
			// si le style de base n'est pas encore défini, on prend le style actuel
			if( _baseStyle == -1 )		_baseStyle 		= index;
		}
		
		/** 
		 * Add one size for this font
		 * @param texture the texture of the font size to add
		 * @param xlm the xml vector of the font size to add
		 * @param size the font size to add
		 * @param bold point out if is a bold font
		 * @param italic point out if it is italic texture
		 **/
		public function add( texture:Texture, xml:XML, size:Number, bold:Boolean = false, italic:Boolean = false ):void
		{
			// récuperer l'index du style actuel
			var index:int = BitmapFontStyle.REGULAR;
			if( bold && italic ) 	index = BitmapFontStyle.BOLD_ITALIC;	
			else if( bold )			index = BitmapFontStyle.BOLD;
			else if( italic )		index = BitmapFontStyle.ITALIC;
			
			// créer le BitmapFontStyle pour le style si il n'existe pas encore
			if( !mFontStyles[index] )	mFontStyles[index] = new BitmapFontStyle( index, new <Texture>[texture], new <XML>[xml], new <Number>[size] );
				// ajouter la taille de font au BitmapFontStyle
			else						mFontStyles[index].add( texture, xml, size );
			
			// si le helperImage n'existe pas encore on le crée
			if( !mHelperImage )			mHelperImage 	= new Image( texture );
			// si eucune taille de base n'est définie on prend la taille actuelle
			if( _baseSize == -1 )		_baseSize 		= size;
			// si le style de base n'est pas encore défini, on prend le style actuel
			if( _baseStyle == -1 )		_baseStyle 		= index;
		}
		
		/** Dispose the associated BitmapFontStyle's */
		public function dispose():void
		{
			for( var i:int = 0; i<BitmapFontStyle.NUM_STYLES; ++i )	
			{
				if( mFontStyles[i] ) mFontStyles[i].dispose();
			}
			mFontStyles.fixed 	= false;
			mFontStyles.length 	= 0;
			mFontStyles 		= null;
		}
		
		/** 
		 * Fill the QuadBatch with text, no reset will be call on the QuadBatch
		 * @param quadBatch the QuadBatch to fill
		 * @param width container width
		 * @param height container height
		 * @param text the text String
		 * @param fontSizes (default null->base size) the array containing the size by char. (if shorter than the text, the last value is used for the rest)
		 * @param styles (default null->base style) the array containing the style by char. (if shorter than the text, the last value is used for the rest)
		 * @param colors (default null->0xFFFFFF) the array containing the colors by char, no tint -> 0xFFFFFF (if shorter than the text, the last value is used for the rest) 
		 * @param hAlign (default center) horizontal align rule
		 * @param vAlign (default center) vertical align rule
		 * @param autoScale (default true) if true the text will be reduced for fiting the container size (if smaller font size are available)
		 * @param kerning (default true) true if you want to use kerning
		 * @param resizeQuad (default false) if true, the Quad can be bigger tahn width, height if the texte cannot fit. 
		 * @param keepDatas (default null) don't delete the Vector.<CharLocation> at the end if a subclass need it.
		 * @param autoCR (default true) do auto line break or not.
		 * @param maxWidth the max width if resizeQuad is true.
		 * @param hideEmote, if true the emote wont be displayed.
		 * @param minFontSize the minimum font size to reduce to. 
		 **/
		public function fillQuadBatch(quadBatch:QuadBatch, width:Number, height:Number, text:String,
									  fontSizes:Array = null, styles:Array = null, colors:Array = null, underlines:Array = null,
									  hAlign:String="center", vAlign:String="center", autoScale:Boolean=true, 
									  kerning:Boolean=true, resizeQuad:Boolean = false, keepDatas:Object = null, 
									  autoCR:Boolean = true, maxWidth:int = 900, hideEmotes:Boolean = false, minFontSize:int = 10 ):void
		{
			// découper le tableau de couleur pour ignorer les caracteres à remplacer par des emotes
			if( _emotesTxt )
			{
				var lenC:int, lenU:int;
				var txtlen:int = text.length-1;
				for( var i:int = txtlen; i>=0; --i )
				{
					var emlen:int = _emotesTxt.length;
					for( var e:int = 0; e<emlen; ++e )
					{
						lenC = lenU = _emotesTxt[e].length;
						if( text.charAt(i) == _emotesTxt[e].charAt(0) && text.substr(i,lenC) == _emotesTxt[e] )
						{
							if( lenC >= colors.length )	lenC = colors.length-1;
							colors.splice(i,lenC-1);
							
							if( lenU >= underlines.length )	lenU = underlines.length-1;
							underlines.splice(i,lenU-1);
							break;
						}
					}
				}
			}
			
			// générer le tableau de CharLocation
			var charLocations	:Vector.<CharLocation> 	= arrangeChars( width, height, text, fontSizes.concat(), styles.concat(), hAlign, vAlign, autoScale, kerning, resizeQuad, autoCR, maxWidth, minFontSize );
			
			// cas foireux pour le texte qui apparait mots à mots
			if( keepDatas )			keepDatas.loc = CharLocation.cloneVector( charLocations );
			if( !quadBatch )	
			{
				CharLocation.rechargePool();
				return;
			}
			
			// récupérer le nombre de caractères à traiter
			var numChars		:int 					= charLocations.length;
			
			// si le tableau de couleur est vide ou null, on met du 0xFFFFFF par défaut (0xFFFFFF -> no modif)
			if( !colors || colors.length == 0 )	colors = [0xFFFFFF];
			
			// limitation du nombre d'images par QuadBatch 
			if( numChars > 8192 )	throw new ArgumentError("Bitmap Font text is limited to 8192 characters.");
			
			// forcer le tint = true pour pouvoir avoir plusieurs couleur de texte
			mHelperImage.alpha = 0.999;
			
			var color			:*;
			var underline		:Boolean;
			var prevUnderline	:Boolean;
			var nextUnderLine	:Boolean;
			var margin			:int;
			var charLocation	:CharLocation;
			// parcourir les caractères pour les placer sur le QuadBatch
			for( i=0; i<numChars; ++i )
			{
				if( !charLocations[i] || hideEmotes && charLocations[i].isEmote )
				{
					continue;
				}
				
				if( charLocations[i].doTint )
				{
					// récupérer la couleur du caractère et colorer l'image
					if( i < colors.length )
					{
						color = colors[i];
					}
					else
					{
						color = colors[colors.length-1];
					}
					
					if( color is Array )
					{
						mHelperImage.setVertexColor(0, color[0]);
						mHelperImage.setVertexColor(1, color[1]);
						mHelperImage.setVertexColor(2, color[2]);
						mHelperImage.setVertexColor(3, color[3]);
					}
					else
					{
						mHelperImage.color = color;
					}
				}
				else
				{
					mHelperImage.color = 0xFFFFFF;
				}
				
				// récupérer le CharLocation du caractère actuel
				charLocation = charLocations[i];
				// appliquer la texture du caractere à l'image
				mHelperImage.texture = charLocation.char.texture;
				// réajuster al taille de l'image pour la nouvelle texture
				mHelperImage.readjustSize();
				// placer l'image
				mHelperImage.x = charLocation.x;
				mHelperImage.y = charLocation.y;
				// scaler l'image
				mHelperImage.scaleX = mHelperImage.scaleY = charLocation.scale;
				// ajouter l'image au QuadBatch
				quadBatch.addImage( mHelperImage );
				
				// creating underlines
				prevUnderline = underline;
				if( i < underlines.length )
				{
					underline = underlines[i];
					if( i+1 < underlines.length )	nextUnderLine = underlines[i+1];
					else							nextUnderLine = underline;
				}
				else	underline = nextUnderLine = underlines[underlines.length-1];
				
				if( underline )
				{
					margin = (i == 0 || i == numChars-1 || !prevUnderline || !nextUnderLine ) ? 1 : charLocation.width>>1;
					//add baseLine
					mHelperImage.texture = _underlineTexture;
					mHelperImage.readjustSize();
					mHelperImage.scaleX = mHelperImage.scaleY = 1;
					mHelperImage.x = charLocation.x-margin;
					mHelperImage.y = int(charLocation.y-charLocation.yOffset+2);
					mHelperImage.width = charLocation.width+margin*2;
					quadBatch.addImage(mHelperImage);
				}
			}
			
			CharLocation.rechargePool();
		}
		
		public function getIndex(id:int, text:String ):int
		{
			if( id<=0)			return 0;
			var numChars		:int 		= text.length;
			if( id<numChars )	numChars 	= id;
			var len				:int 		= id;
			
			if( _emotesTxt )
			{
				for( var i:int=0; i<numChars; ++i )
				{
					for( var e:int = 0; e<_emotesTxt.length; ++e )
					{
						if( text.charAt(i) == _emotesTxt[e].charAt(0) && text.substr(i,_emotesTxt[e].length) == _emotesTxt[e] )
						{
							len -= _emotesTxt[e].length-1;
							break;
						}
					}
				}
			}
			return len;
		}
		
		/** Arranges the characters of a text inside a rectangle, adhering to the given settings. 
		 *  Returns a Vector of CharLocations. */
		private function arrangeChars( width:Number, height:Number, text:String, 
									   fontSizes:Array = null, styles:Array = null, 
									   hAlign:String="center", vAlign:String="center", 
									   autoScale:Boolean=true, kerning:Boolean=true, resizeQuad:Boolean = false, 
									   autoCR:Boolean = true, maxWidth:int = 900, minFontSize:int = 10 ):Vector.<CharLocation>
		{
			// si pas de texte on renvoi un tableau vide
			if( text == null || text.length == 0 ) 		return CharLocation.vectorFromPool();
			
			// aucun style définit, on force le style de base
			if( !styles || styles.length == 0 ) 		styles 		= [_baseStyle];
			
			// aucune taille définie, on force la taille de base
			if( !fontSizes || fontSizes.length == 0 )	fontSizes 	= [_baseSize];
			
			var i:int;
			// passe a true une fois qu'on a fini de rendre le texte
			var finished			:Boolean = false;
			// une charLocation pour remplir le vecteur de lignes
			var charLocation		:CharLocation;
			// le nombre de caracteres à traiter
			var numChars			:int;
			// la hauteur de ligne pour le plus gros caractère
			//var biggestLineHeight	:int;
			// la taille de font du caractere actuel
			var sizeActu			:int;
			// la style de font du caractere actuel
			var styleActu			:int;
			// le scale dont on va se servir
			var scaleActu			:Number = 1;
			
			while( !finished )
			{
				// init/reset le tableau de lignes
				lines.length 		= 0;
				linesSizes.length 	= 0;
				baselines.length 	= 0;
				
				
				var lineStart		:int		= 0;
				var emoteInLine		:int 		= 0;
				var lastWhiteSpace	:int 		= -1;
				var lastWhiteSpaceL	:int 		= -1;
				var lastCharID		:int 		= -1;
				var currentX		:Number 	= 0;
				var currentY		:Number 	= 0;
				var currentLine		:Vector.<CharLocation> = CharLocation.vectorFromPool();
				var currentMaxSize	:Number = 0;
				var currentMaxSizeS	:Number = 0;
				var realMaxSize		:Number = 0;
				var lineHeight		:Number;
				var baseLine		:Number;
				var currentMaxBase	:Number = 0;
				// reset reduced sizes
				_reducedSizes 		= null;
				
				numChars = text.length;
				for( i = 0; i<numChars; ++i )
				{
					// récupérer la taille actuelle
					if( i < fontSizes.length )		sizeActu 	= fontSizes[i];
					// récupérer le syle actuel
					if( i < styles.length )			styleActu 	= styles[i];
					
					// style erroné on prend le stle de base
					if( styleActu > BitmapFontStyle.NUM_STYLES || !mFontStyles[styleActu] )	styleActu = _baseStyle;
					
					// le size index pour pas avoir a le recuperer a chaque fois
					var sizeIndex	:int = mFontStyles[styleActu].getBiggerOrEqualSizeIndex( sizeActu );
					// reset le isEmote
					var isEmote		:Boolean 	= false;
					// c'est une nouvelle ligne donc la ligne n'est surrement pas finie
					var lineFull	:Boolean 	= false;
					// récupérer le CharCode du caractère actuel
					var charID		:int 		= text.charCodeAt(i);
					// récupérer le BitmapChar du caractère actuel
					var char		:BitmapChar = mFontStyles[styleActu].getChar( charID, sizeIndex );
					// le caractère n'est pas disponible, on remplace par un espace
					if( char == null )
					{
						if( charID != CHAR_NEWLINE && charID != CHAR_CARRIAGE_RETURN )	charID = CHAR_SPACE;
						char = mFontStyles[styleActu].getChar( CHAR_SPACE, sizeIndex );
					}
					
					// calculate scale
					scaleActu 		= sizeActu / mFontStyles[styleActu].getSizeAtIndex(sizeIndex);
					lineHeight 		= mFontStyles[styleActu].getLineHeightForSizeIndex(sizeIndex);
					baseLine 		= mFontStyles[styleActu].getBaseLine(sizeIndex)
					
					if( baseLine > currentMaxBase )					currentMaxBase 	= baseLine;
					if( lineHeight > currentMaxSize )				currentMaxSize 	= lineHeight;
					if( lineHeight*scaleActu > currentMaxSizeS )	currentMaxSizeS = lineHeight*scaleActu;
					if( currentMaxSizeS > realMaxSize )				realMaxSize 	= currentMaxSizeS;
					
					if( _emotesTxt )
					{
						for( var e:int = 0; e<_emotesTxt.length; ++e )
						{
							if( text.charAt(i) == _emotesTxt[e].charAt(0) && text.substr(i,_emotesTxt[e].length) == _emotesTxt[e] )
							{
								char = _emotesTextures[e];
								i += _emotesTxt[e].length-1;
								isEmote = true;
								break;
							}
						}
						if( isEmote && char.height > realMaxSize )
						{
							// si l'emote est plus grand on descend tous les caracteres de la ligne
							var dif:int = ( (char.height - realMaxSize) >> 1 )+2;
							currentY += dif;
							for( var a:int = 0; a<currentLine.length; ++a )
							{
								currentLine[a].y += dif;
							}
							realMaxSize = char.height;
						}
					}
					if( isEmote )	scaleActu = 1;
					
					// retour à la ligne
					if( charID == CHAR_NEWLINE || charID == CHAR_CARRIAGE_RETURN )		lineFull = true;
					else
					{
						// on enregistre le placement du dernier espace
						if( charID == CHAR_SPACE || charID == CHAR_TAB || charID == CHAR_SLASH )	
						{
							lastWhiteSpace = i;
							lastWhiteSpaceL = i-lineStart-emoteInLine;
						}
						// application du kerning si activé
						if( kerning && lastCharID >= 0 ) 		currentX += char.getKerning(lastCharID)*scaleActu;
						// ajouter le nombre de carateres pris par une emote 
						if( isEmote )							emoteInLine += _emotesTxt[e].length-1;
						
						// créer un CharLocation ou le récupérer dans la pool
						charLocation 			= CharLocation.instanceFromPool(char);
						charLocation._lineHeight= lineHeight;
						charLocation.style 		= styleActu;
						charLocation.isEmote 	= isEmote;
						charLocation.scale		= scaleActu;
						charLocation.baseLine	= baseLine;
						
						// définir la position du caractère en x
						charLocation.x 			= currentX + charLocation.xOffset;
						// définir la position du caractère en y
						charLocation.y 			= currentY + charLocation.yOffset;
						// si c'est un emote on ne teinte pas l'image
						charLocation.doTint 	= !isEmote;
						
						// on ajoute le caractère au tableau
						currentLine.push( charLocation );
						
						// on met a jour la position x du prochain caractère si ce n'est pas le premier espace d'une ligne
						if( currentLine.length != 1 || charID != CHAR_SPACE )	currentX += charLocation.xAdvance;
						
						// on enregistre le CharCode du caractère
						lastCharID = charID;
						
						// fin de ligne car dépassement de la largeur du conteneur
						if( charLocation.x + charLocation.width > width )
						{
							// tenter voir si on peut mettre le texte a la ligne
							if( autoCR && (resizeQuad || currentY + 2*currentMaxSizeS + _lineSpacing <= height) )
							{
								// si autoscale est a true on ne doit pas couper le mot en 2
								if( autoScale && lastWhiteSpace < 0 )		
								{
									if( resizeQuad )	
									{
										if( width >= maxWidth )		goto ignore;
										goto suite;
									}
									else if( !_reduceSizes(fontSizes, minFontSize) )	
									{
										goto ignore;
									}
									break;
								}
								
								ignore:
								
								// si c'est un emote on retourne au debut de l'emote avant de couper
								if( isEmote )			i -= _emotesTxt[e].length-1;
								
								if( lastWhiteSpace >= 0 && lastWhiteSpaceL >= 0 )
								{
									// si on a eu un espace on va couper apres le dernier espace sinon on coupe à lindex actuel
									var numCharsToRemove	:int = currentLine.length - lastWhiteSpaceL+1; //i - lastWhiteSpace + 1;
									var removeIndex			:int = lastWhiteSpaceL + 1; //lastWhiteSpace+1;//currentLine.length - numCharsToRemove + 1;
									
									// couper la ligne
									var temp:Vector.<CharLocation> = CharLocation.vectorFromPool();
									var l:int = currentLine.length;
									
									for( var t:int = 0; t<l; ++t )
									{
										if( t < removeIndex || t >= removeIndex+numCharsToRemove )	temp.push( currentLine[t] );
									}
									
									// il faut baisser la taille de la font -> on arrete la
									if( temp.length == 0 )	
									{
										if( resizeQuad )	goto suite;
										_reduceSizes(fontSizes, minFontSize);
										break;
									}
									currentLine = temp;
									i = lastWhiteSpace;
								}
								
								lineFull = true;
								// si le prochain caractere est un saut de ligne, on l'ignore
								if( text.charCodeAt(i+1) == CHAR_CARRIAGE_RETURN || text.charCodeAt(i+1) == CHAR_NEWLINE )	
								{
									++i;
								}
							}
							else
							{
								_reduceSizes(fontSizes, minFontSize);
								break;
							}
						}
						
					}
					
					suite:
					
					// fin du texte
					if( i == numChars - 1 )
					{
						lines.push( currentLine );
						linesSizes.push( currentMaxSize );
						baselines.push( currentMaxBase );
						//currentMaxSize = 0;
						finished = true;
					}
						// fin de ligne
					else if( lineFull )
					{
						if( resizeQuad && charLocation.x + charLocation.width > width )
						{
							if( width < maxWidth )
							{
								width = charLocation.x + charLocation.width <= maxWidth ? charLocation.x + charLocation.width : maxWidth;
								break;
							}
						}
						
						currentLine.push(null);
						lines.push( currentLine );
						linesSizes.push( currentMaxSize );
						baselines.push( currentMaxBase );
						
						// on a la place de mettre une nouvelle ligne
						if( resizeQuad || currentY + 2*currentMaxSizeS + _lineSpacing <= height )
						{
							// créer un tableau pour la nouvelle ligne
							currentLine = CharLocation.vectorFromPool();
							// remettre le x à 0
							currentX = 0;
							// mettre le y à la prochaine ligne
							currentY += realMaxSize+_lineSpacing;
							// reset lastWhiteSpace index
							lastWhiteSpace = -1;
							lastWhiteSpaceL = -1;
							emoteInLine = 0;
							lineStart = i+1;
							// reset lastCharID vu que le kerning ne va pas s'appliquer entre 2 lignes
							lastCharID = -1;
							// reset la taille max pour la ligne
							currentMaxSizeS = currentMaxBase = realMaxSize = 0;
							currentMaxBase = 0;
						}
						else
						{
							// il faut baisser la taille de la font -> on arrete la
							_reduceSizes(fontSizes, minFontSize);
							//trace( 'pas de place pour une nouvelle ligne', text );
							break;
						}
					}
				} // for each char
				
				// si l'autoscale est activé et que le texte ne rentre pas dans la zone spécifié, on réduit la taille de la police
				if( (autoScale || (resizeQuad && width >= maxWidth)) && !finished && _reducedSizes )
				{
					fontSizes 		= _reducedSizes;
					_reducedSizes 	= null;
				}
				else if( !finished && (!resizeQuad || width >= maxWidth) )
				{
					// on peut rien y faire on y arrivera pas c'est fini
					finished = true; 
					if( currentLine )
					{
						// supprimer le dernier caractere vu que si on est ici c'est qu'il passait pas 
						currentLine.pop();
						lines.push( currentLine );
						linesSizes.push( currentMaxSize );
						baselines.push( currentMaxBase );
					}
				}
			} // while (!finished)
			
			// le tableau de positionnement final des caractères
			var finalLocations	:Vector.<CharLocation> 	= CharLocation.vectorFromPool();//new <CharLocation>[];
			// le nombre de lignes
			var numLines		:int 					= lines.length;
			// le y max du texte
			var bottom			:Number 				= currentY + currentMaxSize;//biggestLineHeight;
			// l'offset y
			var yOffset			:int 					= 0;
			// la ligne à traiter
			var line			:Vector.<CharLocation>;
			// un j
			var j:int;
			
			// la taille de la ligne la plus longue utile pour les LEFT_CENTERED et RIGHT_CENTERED
			var longestLineWidth:Number = 0;
			
			if( hAlign == HTMLTextField.RIGHT_CENTERED || hAlign == HTMLTextField.LEFT_CENTERED )
			{
				for( i=0; i<numLines; ++i )
				{
					// récupérer la ligne actuelle
					line 		= lines[i];
					// récupérer le nombre de caractères sur la ligne
					numChars 	= line.length;
					// si ligne vide -> on passe à la suivante
					if( numChars == 0 ) 	continue;
					
					for( j = numChars-1;j>=0; --j )
					{
						if( !lines[i][j] || lines[i][j].char.charID == CHAR_SPACE )		continue;
						
						if( lines[i][j].x+lines[i][j].width > longestLineWidth )	
							longestLineWidth = lines[i][j].x + lines[i][j].width;
						
						break;
					}
				}
			}
			
			var c:int, xOffset:int, right:Number, lastLocation:CharLocation;
			// parcourir les lignes
			for( var lineID:int=0; lineID<numLines; ++lineID )
			{
				// récupérer la ligne actuelle
				line 		= lines[lineID];
				// récupérer le nombre de caractères sur la ligne
				numChars 	= line.length;
				
				// si ligne vide -> on passe à la suivante
				if( numChars == 0 ) continue;
				
				// l'offset x
				xOffset	= 0;
				// la position du dernier caractère de la ligne
				j = 1;
				lastLocation = line[line.length-j];
				while( lastLocation == null && line.length-j >= 0)
				{
					lastLocation = line[line.length-j++];
				}
				// le x max de la ligne
				right = lastLocation ? lastLocation.x - lastLocation.xOffset + lastLocation.xAdvance : 0;
				
				// calculer l'offset x en fonction de la règle d'alignement horizontal
				if( hAlign == HAlign.RIGHT )       					xOffset =  width - right;
				else if( hAlign == HAlign.CENTER ) 					xOffset = (width - right) / 2;
				else if( hAlign == HTMLTextField.RIGHT_CENTERED ) 	xOffset = longestLineWidth + (width - longestLineWidth) / 2 - right;
				else if( hAlign == HTMLTextField.LEFT_CENTERED ) 	xOffset = (width - longestLineWidth) / 2;
				
				// parcourir les caractères
				for( c=0; c<numChars; ++c )
				{
					// récupérer le CharLocation
					charLocation 		= line[c];
					if( charLocation )
					{
						// appliquer l'offset x et le _globalScale à la positon x du caractère
						charLocation.x = charLocation.x + xOffset;
						// aligner les emotes
						if( charLocation.isEmote )	charLocation.y -= (charLocation.height-linesSizes[lineID])>>1;
						// appliquer l'offset y et le scale à la positon y du caractère
						charLocation.y = charLocation.y + yOffset;
						// ajouter le caractere au tableau
						finalLocations.push(charLocation);
					}
				}
			}
			
			lines.length 		= 0;
			linesSizes.length 	= 0;
			
			return finalLocations;
		}
		
		/** les tailles réduites **/
		private var _reducedSizes	:Array;
		/** reduce the size of all items in the array **/
		[Inline]
		private final function _reduceSizes( sizes:Array, minFontSize:int ):Boolean
		{
			// récupérer la taille du tableau de tailles
			var len			:int = sizes.length;
			var limite		:int = 0;
			var target		:int;
			_reducedSizes 	= [];
			for( var i:int = 0; i<len; ++i )
			{
				target = sizes[i]-1;
				if( target < minFontSize )
				{
					target = minFontSize;
					++limite;
				}
				_reducedSizes[i] = target;
			}
			if( limite >= len-1 )
			{
				_reducedSizes = null;
				return false;
			}
			return true; 
		}
		
		/** The name of the font as it was parsed from the font file. */
		public function get name():String { return mName; }
		
		/** The smoothing filter that is used for the texture. */ 
		public function get smoothing():String { return mHelperImage.smoothing; }
		public function set smoothing(value:String):void { mHelperImage.smoothing = value; } 
		
		public function getAvailableSizesForStyle( style:int ):Vector.<Number>
		{
			return mFontStyles[style] ? mFontStyles[style].availableSizes : null;
		}
		
		private var _lineSpacing:int = 0;
		public function set lineSpacing( value:int ):void
		{
			_lineSpacing = value;
		}
		
		public function getChar( style:int, charID:int, sizeIndex:int ):BitmapChar
		{
			return mFontStyles[style].getChar( charID, sizeIndex );
		}
		
		public function getBaseLine( style:int, sizeIndex:int ):Number
		{
			return mFontStyles[style].getBaseLine(sizeIndex);
		}
		
		public function getLineHeight( style:int, sizeIndex:int ):Number
		{
			return mFontStyles[style].getLineHeightForSizeIndex(sizeIndex);
		}
	}
}