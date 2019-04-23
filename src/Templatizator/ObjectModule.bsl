
Var mTemplateInString;

Var mIterators;

Var mStack;

Var SearchingNextElse; // book

Var StopProccessingOfBlockIF;   // bool

Var HTML; //this string variable will be returned as a result.


#Region API

// PropertiesWithDateValuesNames - string - список полей JSON с типом Дата для метода ReadJSON()
Function CreateHTMLServer( PropertiesWithDateValuesNames = "" ) Export
	
	HTML = "";
	
	CopyTemplateTextToVariable();
	
	If TemplateData = Undefined Then
		TemplateData 			= GetTemplateDataFromJSON( PropertiesWithDateValuesNames );	
	EndIf; 
	
	TemplateTree = CreateTemplateTree( Undefined );
	
	HTML = FillTemplateByRecursion( TemplateTree.Rows );
	
	HTML = RemoveBlankRows(HTML);
	
	Return HTML;
	
EndFunction

#EndRegion

////////////////////////////////////////////////////////////

Function CreateTemplateTree(TemplateTree) Export
	
	If TemplateTree = Undefined Then
		TemplateTree = New ValueTree;
		TemplateTree.Columns.Add("Text");
		TemplateTree.Columns.Add("TemplateKind");
		
	EndIf; 
	 	
	NextDelimiter = FindNextOpenDelimiter(mTemplateInString);
	
	While NextDelimiter > 0 Do
		
		ТекстПередШаблоном = Лев(mTemplateInString, NextDelimiter-1);
		
		NewRow = TemplateTree.Rows.Add();
		NewRow.Text = ТекстПередШаблоном;
		
		// найти закрытие шаблона
		КонецШаблона = FindNextClosedDelimiter(mTemplateInString);
		
		TempText = Mid(mTemplateInString, NextDelimiter, КонецШаблона - NextDelimiter + 2);
		
		NewRow = TemplateTree.Rows.Add();
		NewRow.Text = TempText;
			
		If ThisIsTemplateOfCycle(TempText) Then
			
			NewRow.TemplateKind = "Цикл";
			
			mTemplateInString = Mid(mTemplateInString, КонецШаблона+2);
			
			CreateTemplateTree(NewRow);
			NextDelimiter = FindNextOpenDelimiter(mTemplateInString);
			Continue;
			
		ElsIf ThisIsTemplateOfCycleWithCounter(TempText) Then
			
			NewRow.TemplateKind = "ЦиклПоСчетчику";
			
			mTemplateInString = Mid(mTemplateInString, КонецШаблона+2);
			
			CreateTemplateTree(NewRow);
			NextDelimiter = FindNextOpenDelimiter(mTemplateInString);
			Continue;
			
		ElsIf ThisIsTemplateOfEndOfCycle(TempText) Then
			
			NewRow.TemplateKind = "КонецЦикла";
			
			mTemplateInString = Mid(mTemplateInString, КонецШаблона+2);
			
			Return Undefined;
			
		ElsIf ThisIsTemplateOfConditionIf(TempText) Then
			
			NewRow.TemplateKind = "Если";
			mTemplateInString = Mid(mTemplateInString, КонецШаблона+2);
			
			CreateTemplateTree(NewRow);
			NextDelimiter = FindNextOpenDelimiter(mTemplateInString);
			Continue;
			
		ElsIf ThisIsTemplateOfElsIf(TempText) Then
			
			NewRow.TemplateKind = "ИначеЕсли";
			mTemplateInString = Mid(mTemplateInString, КонецШаблона+2);
						
			NextDelimiter = FindNextOpenDelimiter(mTemplateInString);			
			Continue;
			
		ElsIf ThisIsTemplateOfElse(TempText) Then
			
			NewRow.TemplateKind = "Иначе";
			mTemplateInString = Mid(mTemplateInString, КонецШаблона+2);
			
			NextDelimiter = FindNextOpenDelimiter(mTemplateInString);
			Continue;
			
		ElsIf ThisIsTemplateOfEndIf(TempText) Then
			
			NewRow.TemplateKind = "КонецЕсли";
			
			mTemplateInString = Mid(mTemplateInString, КонецШаблона+2);
			
			Return Undefined;
			
		EndIf; 
		
		If ThisIsTemplateOfVariable(TempText) Then
			NewRow.TemplateKind = "Переменная";
		EndIf; 
			
		mTemplateInString = Mid(mTemplateInString, КонецШаблона+2);
				
		NextDelimiter = FindNextOpenDelimiter(mTemplateInString);
					
	EndDo;
	
	// добавить хвост шаблона
	NewRow = TemplateTree.Строки.Добавить();
	NewRow.Text = mTemplateInString;
		
	Return TemplateTree;
	
EndFunction

////////////////////////////////////////////////////////////

Function FillTemplateByRecursion( Rows ) Export
	
	For Each Str In Rows Do
				
		If ValueIsFilled(Str.TemplateKind) Then			
			
	
			If Lower(Str.TemplateKind) = "цикл" Then

				// получим коллекцию
				Коллекция = Undefined;
				CollectionName = GetCollectionName( Str.Text );			
				TemplateData.Свойство(CollectionName , Коллекция);
				
				ИмяПеременнойЦикла = Lower(GetNameOfVariableOfCycle(Str.Text)); 
				сч = 1;
				For Each Эл In Коллекция Do
					
					mIterators.Вставить(ИмяПеременнойЦикла, Эл);
					                           
			    	FillTemplateByRecursion( Str.Rows );
					
					mIterators.Удалить(ИмяПеременнойЦикла);
					сч = сч + 1;
						
				EndDo;
				
			ElsIf Lower(Str.TemplateKind) = "циклпосчетчику" Then

				// слово count в цикле: for count = 1 to 10 do
				CounterName = Lower(GetNameOfVariableOfCycleWighCounter( Str.Text ));
				
				For count = GetLowerBoundOfCycle( Str.Text ) To GetUpperBoundOfCycle( Str.Text ) Do
					
					mIterators.Вставить(CounterName, count);
					                           
			    	FillTemplateByRecursion( Str.Rows );
					
					mIterators.Удалить(CounterName);
						
				EndDo;
				
				
			ElsIF Lower(Str.TemplateKind) = "конеццикла" Then
				// Do nothing
				
			ElsIF Lower(Str.TemplateKind) = "если" Then
				
				If EvaluateExpression(ExtractExpressionIF( Str.Text )) = True Then
					
					StopProccessingOfBlockIF=True;
						
					FillTemplateByRecursion( Str.Rows );
					StopProccessingOfBlockIF=False;
				Else 
					
					SearchingNextElse = True;
					FillTemplateByRecursion( Str.Rows );
					SearchingNextElse = False;
				EndIf;
				
			ElsIF Lower(Str.TemplateKind) = "иначеесли" Then
				
				If StopProccessingOfBlockIF=True Then
					StopProccessingOfBlockIF=False;
					Return Undefined;
				EndIf; 
				
				If EvaluateExpression(ExtractExpressionElsIF( Str.Text )) = True Then
					
					SearchingNextElse = False;
					StopProccessingOfBlockIF = True;
				Else 
					
					SearchingNextElse = True;
					StopProccessingOfBlockIF = False;
				EndIf;

			ElsIF Lower(Str.TemplateKind) = "иначе" Then
				
				SearchingNextElse = False;

				If StopProccessingOfBlockIF=True Then
					StopProccessingOfBlockIF=False;
					Return Undefined;
				EndIf;
				
				StopProccessingOfBlockIF=False;
				
			Else 
				// вид шаблона = "Переменная" или ПеременнаяЦикла (но это не вид шаблона)
				
				If SearchingNextElse = False Then	
					Рез = GetValueOfVariable( Str.Text, Str.TemplateKind );
					HTML=HTML+Рез;
					
				Else 
					// тут возможно состояние "ИщемСледующуюВеткуИначе". ничего не делаем, переходим к следующей строке
				EndIf; 

				
			EndIf; 			
			
		Else 
			
			
			If SearchingNextElse = False Then
				HTML = HTML + Str.Text;
			Else 
				// тут возможно состояние "ИщемСледующуюВеткуИначе". ничего не делаем, переходим к следующей строке
			EndIf; 
				
		EndIf; 
		
	EndDo;
	
	Return HTML;
	
EndFunction

////////////////////////////////////////////////////////////

Function GetTemplateDataFromJSON( PropertiesWithDateValuesNames = "" )
		
	Reader = New JSONReader;
	Reader.SetString(JSON);
	If PropertiesWithDateValuesNames <> "" Then
		jData=ReadJSON(Reader,,PropertiesWithDateValuesNames);
	Else 
		jData=ReadJSON(Reader);
	EndIf; 
	
	Reader.Close();
	Return jData;
	
EndFunction
 
////////////////////////////////////////////////////////////

Function RemoveBlankRows(HTML)
	t = New TextDocument;
	t.SetText(HTML);
	
	newT = New TextDocument;
	
	For count = 1 To t.LineCount() Do
		r = TrimAll(t.GetLine(count));
		If r <> "" Then
			newT.addLine(r);
		EndIf; 
	EndDo;
	
	Return newT.ПолучитьТекст();
	
EndFunction
 
//Usage:
//	Expr = ExtractExpressionIF( Str.Text )
Function ExtractExpressionIF(Val TextOfExpression)
	
	sTextOfExpression = Lower(TextOfExpression);
	p1rus=StrFind(sTextOfExpression, Lower("{% Если "));
	p2rus=StrFind(sTextOfExpression, Lower("Тогда %}"));
	p1eng=StrFind(sTextOfExpression, Lower("{% If "));
	p2eng=StrFind(sTextOfExpression, Lower("Then %}"));
	If p1rus>0 AND p2rus>0 Then
		
		Expression 	= Mid (TextOfExpression, p1rus + 8, p2rus - p1rus - 9);
		
	ElsIf p1eng>0 AND p2eng>0 Then
		
		Expression 	= Mid (TextOfExpression, p1eng + 6, p2eng - p1eng - 7);
		
	EndIf; 
	
	Return Expression;
	
EndFunction

//Usage:
//	Expr = ExtractExpressionElsIF( Str.Text )
Function ExtractExpressionElsIF(Val TextOfExpression)
	
	TextOfExpression = Lower(TextOfExpression);
	
	If StrFind(TextOfExpression, Lower("{% ИначеЕсли "))>0 AND StrFind(TextOfExpression, Lower("Тогда %}"))>0 Then
		
		Start 		= StrFind(TextOfExpression, Lower("{% ИначеЕсли "));
		End 		= StrFind(TextOfExpression, Lower("Тогда %}"));
		Expression 	= Mid (TextOfExpression, Start + 11, End - Start - 12);
		
	ElsIf StrFind(TextOfExpression, Lower("{% ElsIf "))>0 AND StrFind(TextOfExpression, Lower("Then %}"))>0 Then
		
		Start 		= StrFind(TextOfExpression, Lower("{% ElsIf "));
		End 		= StrFind(TextOfExpression, Lower("Then %}"));
		Expression 	= Mid (TextOfExpression, Start + 9, End - Start - 10);
		
	EndIf; 
	
	Return Expression;
	
EndFunction				

//
Procedure ReplaceIteratorRecursion(Key_, ExpressionText, Val sExpressionText, StartIndex)
		

		p1 = StrFind(sExpressionText, Key_,,StartIndex);
		If p1 > 0 Then
			LeftPart = Left(ExpressionText, p1-1);
			RightPart = Mid(ExpressionText, p1+StrLen(Key_));
			newLeftPart = LeftPart + "mIterators["""+Key_+"""]";
			StartIndex = StrLen(newLeftPart);
			ExpressionText = newLeftPart + RightPart;
			ReplaceIteratorRecursion(Key_, ExpressionText, Lower(ExpressionText), StartIndex);
		Else 
			//return;
		EndIf; 

	
EndProcedure
 

Function EvaluateExpression(Val ExpressionText)
		
	If StrFind(ExpressionText, "&w.")>0 Then
		
		ExpressionText = StrReplace(ExpressionText, "&w.", "TemplateData.");
		
	EndIf; 
	
	// нужно заменить СтрокаДанных на обращение к итераторам в контексте модуля
	
	// Замену делаем сложным путем, через поиск в копии строки в нижнем регистре,
	// чтобы обеспечить регистронезависимую запись ключевых слов.
	// В соответствии "mIterators" итераторы хранятся в нижнем регистре.
	// Однако, в этой же строке могут быть текстовые константы, для которых надо 
	// сохранить регистр символов.
	
	sExpressionText=Lower(ExpressionText);
		
	For Each Iterator In mIterators Do
		StartIndex = 1;
		ReplaceIteratorRecursion(Iterator.Key, ExpressionText, sExpressionText, StartIndex);
		sExpressionText=Lower(ExpressionText);
	EndDo;	
	
	
	Return Eval(ExpressionText);
	
EndFunction
 
Function FindNextOpenDelimiter(mTemplateInString)
		
	s1 = StrFind(mTemplateInString, "{%");
	s2 = StrFind(mTemplateInString, "{{");
	
	If s1>0 And s2>0 And s1<s2 Then
	
		Return s1;
	ElsIf s1>0 And s2>0 And s2<s1 Then

		Return s2;
	ElsIf s1>0 And s2=0 Then

		Return s1;
	ElsIf s1=0 And s2>0 Then
	
		Return s2;
	Else 

		Return s2;
	EndIf; 
	
EndFunction

Function FindNextClosedDelimiter(mTemplateInString)
		
	s1 = StrFind(mTemplateInString, "%}");
	s2 = StrFind(mTemplateInString, "}}");
	
	If s1>0 And s2>0 And s1<s2 Then

		Return s1;
	ElsIf s1>0 And s2>0 And s2<s1 Then

		Return s2;
	ElsIf s1>0 And s2=0 Then
		
		Return s1;
	ElsIf s1=0 And s2>0 Then

		Return s2;
	Else 
		
		Return s2;
	EndIf; 
	
EndFunction

////////////////////////////////////////////////////////////

Function GetValueOfVariable( Val TempText, TemplateKind ) Export
	
	Рез = "";
	TempText=СокрЛП(TempText);
	
	ЗначениеСвойства = Undefined;

	Key_ = Lower(ReplaceSpecialSymbols(TempText));
	
	OpenBracketPosition = StrFind(Key_, "[");
	ClosedBracketPosition = StrFind(Key_, "]"); 
	
	If OpenBracketPosition>0 AND ClosedBracketPosition>0 Then
		CycleCounterName = Lower(GetCounterNameFromBrackets(Key_));
		If mIterators[CycleCounterName]<> Undefined Then
			CycleCounterValue = mIterators[CycleCounterName];
			CollectionName = GetCollectionNameFromBrackets(Key_);
			TemplateData.Свойство(CollectionName, Рез);
			Return Рез[CycleCounterValue];
		EndIf;
	EndIf;
	
	
	DotPosition = StrFind(Key_, ".");
	If DotPosition > 0 Then
		
		// обнаружена вложенная коллекция
		
		CollectionName = Lower(Left(Key_,DotPosition-1));
		
		NestedCollection = Undefined;
		
		If mIterators[CollectionName]<> Undefined Then
			NestedCollection = mIterators[CollectionName];
		
		Else
			TemplateData.Свойство(CollectionName, NestedCollection);
		
		EndIf;
		
		If NOT ValueIsFilled(NestedCollection) Then
			Raise "Не найдено значение для шаблона "+Строка(CollectionName);	
		EndIf; 
		
		Key_ = Mid( Key_, DotPosition+1 );
		
		Push(TemplateData);
		
		TemplateData = NestedCollection;
		
		Рез = GetValueOfVariable( Key_, TemplateKind );
		
		Pop(TemplateData);
		
	Else 
		
		// сначала проверим наличие переменной цикла
		// это слово "Элемент" в конструкции "Для каждого Элемент из Коллекция Цикл"
		
		If mIterators[Key_]<> Undefined Then
			Рез = mIterators[Key_];
	
		Else
	        If ТипЗнч(TemplateData) = Тип("Структура") Then
				
				TemplateData.Свойство(Key_, ЗначениеСвойства);
				
			ElsIf TemplateData["Ссылка"]<>Undefined Then
				// ссылочный объект
				ЗначениеСвойства = TemplateData[Key_];
			EndIf; 
			
			Рез = ЗначениеСвойства;
		EndIf; 
		
	EndIf; 
		
	Return Рез;
	
EndFunction
 
////////////////////////////////////////////////////////////

Function ReplaceSpecialSymbols(Val TempText) Export
		
	Key_ = StrReplace(TempText, "{%", "");
	Key_ = StrReplace(Key_, "%}", "");
	Key_ = StrReplace(Key_, "&w.", "");
	//Key_ = StrReplace(Key_, " ", "");
	Key_ = StrReplace(Key_, "{{", "");
	Key_ = StrReplace(Key_, "}}", "");
	Key_ = TrimAll(Key_);
	Return Key_;
	
EndFunction
 
////////////////////////////////////////////////////////////

Function ItemByIndex(Val TempText)
	
	
EndFunction

////////////////////////////////////////////////////////////

Function GetCounterNameFromBrackets(Val TempText)
		
	OpenBracketPosition = StrFind(TempText, "[");
	ClosedBracketPosition = StrFind(TempText, "]"); 
	Res = Mid(TempText,OpenBracketPosition+1,ClosedBracketPosition-OpenBracketPosition-1);
	Return Res;
	
EndFunction
 
////////////////////////////////////////////////////////////

Function GetCollectionNameFromBrackets(Val TempText)
	
	DotPosition = StrFind(TempText, ".");
	OpenBracketPosition = StrFind(TempText, "[");
	 
	Res = Mid(TempText,DotPosition+1,OpenBracketPosition-DotPosition-1);
	Return Res;
	
EndFunction

////////////////////////////////////////////////////////////

Function ThisIsTemplateOfVariable(TempText) Export
		
	Return StrFind(TempText, "{{")>0;
	
EndFunction
 
Function ThisIsTemplateOfCycle(TempText) Export
	// обрабатывается только один вид циклов
	
	Fields = РазложитьСтрокуВМассивПодстрок(Lower(TempText), " ");
	If Fields.Find("для") <> Undefined AND Fields.Find("каждого") <> Undefined AND Fields.Find("из") <> Undefined AND Fields.Find("цикл") <> Undefined Then
		Return True;	
	EndIf; 
	If Fields.Find("for") <> Undefined AND Fields.Find("each") <> Undefined AND Fields.Find("in") <> Undefined AND Fields.Find("do") <> Undefined Then
		Return True;	
	EndIf;
	
	Return False;
	
	//Return StrFind(Lower(TempText), Lower("Цикл %}"))>0
	//	OR (StrFind(Lower(TempText), Lower("Do %}"))>0 AND StrFind(Lower(TempText), Lower("{% EndDo %}"))= 0);
	
EndFunction
	
Function ThisIsTemplateOfCycleWithCounter(TempText) Export
	
	Fields = РазложитьСтрокуВМассивПодстрок(Lower(TempText), " ");
	If Fields.Find("для") <> Undefined AND Fields.Find("=") <> Undefined AND Fields.Find("по") <> Undefined AND Fields.Find("цикл") <> Undefined Then
		Return True;	
	EndIf; 
	If Fields.Find("for") <> Undefined AND Fields.Find("=") <> Undefined AND Fields.Find("to") <> Undefined AND Fields.Find("do") <> Undefined Then
		Return True;	
	EndIf; 
	
	Return False;
	
EndFunction

Function ThisIsTemplateOfEndOfCycle(TempText) Export
	// обрабатывается только один вид циклов
	
	Return StrFind(Lower(TempText), Lower("{% КонецЦикла %}"))> 0
		OR StrFind(Lower(TempText), Lower("{% EndDo %}"))> 0;
	
EndFunction

Function ThisIsTemplateOfConditionIf(TempText) Export

	Return (StrFind(Lower(TempText), Lower("{% Если"))> 0 И StrFind(Lower(TempText), Lower("Тогда %}"))>0)
		OR (StrFind(Lower(TempText), Lower("{% If"))> 0 И StrFind(Lower(TempText), Lower("Then %}"))>0);
	
EndFunction

Function ThisIsTemplateOfElsIf(TempText) Export

	Return (StrFind(Lower(TempText), Lower("{% ИначеЕсли"))> 0 И StrFind(Lower(TempText), Lower("Тогда %}"))>0)
		OR (StrFind(Lower(TempText), Lower("{% ElsIf"))> 0 И StrFind(Lower(TempText), Lower("Then %}"))>0);
	
EndFunction

Function ThisIsTemplateOfElse(TempText) Export

	Return StrFind(Lower(TempText), Lower("{% Иначе %}"))> 0
		OR StrFind(Lower(TempText), Lower("{% Else %}"))> 0;
	
EndFunction

Function ThisIsTemplateOfEndIf(TempText) Export

	Return StrFind(Lower(TempText), Lower("{% КонецЕсли %}"))> 0
		OR StrFind(Lower(TempText), Lower("{% EndIf %}"))> 0;
	
EndFunction
 
Function GetCollectionName( Val TempText) Export
	
	TempText=TrimAll(TempText);
	Key_ = StrReplace(TempText, "{%", "");
	Key_ = StrReplace(Key_, "%}", "");
	Fields = РазложитьСтрокуВМассивПодстрок(Key_, " ");
	
	Return StrReplace(Fields [4], "&w.", "");
	
EndFunction

Function GetLowerBoundOfCycle( Val TempText) Export
	
	TempText=TrimAll(TempText);
	Key_ = StrReplace(TempText, "{%", "");
	Key_ = StrReplace(Key_, "%}", "");
	Fields = РазложитьСтрокуВМассивПодстрок(Key_, " ");
	// for count = 1 to 10 do
	Return Number(Fields [3]);
	
EndFunction

Function GetUpperBoundOfCycle( Val TempText) Export
	
	TempText=TrimAll(TempText);
	Key_ = StrReplace(TempText, "{%", "");
	Key_ = StrReplace(Key_, "%}", "");
	Fields = РазложитьСтрокуВМассивПодстрок(Key_, " ");
	// for count = 1 to 10 do
	Return Number(Fields [5]);
	
EndFunction

Function GetNameOfVariableOfCycle( Val TempText) Export
	
	TempText=TrimAll(TempText); 
	Key_ = StrReplace(TempText, "{%", "");
	Key_ = StrReplace(Key_, "%}", "");
	Fields = РазложитьСтрокуВМассивПодстрок(Key_, " ");
	
	Return Fields [2]; 
	
EndFunction

Function GetNameOfVariableOfCycleWighCounter( Val TempText) Export
	
	TempText=TrimAll(TempText); 
	Key_ = StrReplace(TempText, "{%", "");
	Key_ = StrReplace(Key_, "%}", "");
	Fields = РазложитьСтрокуВМассивПодстрок(Key_, " ");
	// for count = 1 to 10 do
	Return Fields [1]; 
	
EndFunction

Procedure Push(Variable) Export
	
	mStack.Add(Variable);
	
EndProcedure
 
Procedure Pop(Variable) Export
	
	Peak = mStack.Ubound();
	If Peak >= 0 Then
		Variable = mStack[ Peak ];
		mStack.Delete( Peak );
	EndIf; 
	
EndProcedure

Procedure CopyTemplateTextToVariable() Export
	mTemplateInString=TemplateText;
EndProcedure

#Region Данные_для_теста

Function CreateTemplateData() Export
	
	// структура с данными для подстановки в шаблон

	TemplateData = Новый Структура;

	TemplateData.Вставить("Title", "Шаблонизатор");
	
	Список1 = Новый Массив;
	Список1.Добавить("Элемент 1 списка 1");
	Список1.Добавить("Элемент 2 списка 1");
	Список1.Добавить("Элемент 3 списка 1");

	TemplateData.Вставить("Список", Список1);

	Список2 = Новый Массив;
	Список2.Добавить("Элемент 1 списка 2");
	Список2.Добавить("Элемент 2 списка 2");
	Список2.Добавить("Элемент 3 списка 2");

	TemplateData.Вставить("ВложенныйСписок", Список2);

	// таблицу с данными сделаем в виде массива структур, на всякий случай, чтобы и на клиенте работало
	ТаблицаДанных = Новый Массив;
	СтруктураДанных = Новый Структура;
	НомерСтроки = 1;
	СтруктураДанных.Вставить("RowNum", НомерСтроки);
	СтруктураДанных.Вставить("Account", "Account #5678967890 at Standard Chartered Bank");
	СтруктураДанных.Вставить("TotalAmount", "USD 8.993.340");
	ТаблицаДанных.Добавить(СтруктураДанных);
	НомерСтроки=НомерСтроки+1;

	СтруктураДанных = Новый Структура;
	СтруктураДанных.Вставить("RowNum", НомерСтроки);
	СтруктураДанных.Вставить("Account", "Account #1100000 at HSBC Singapore");
	СтруктураДанных.Вставить("TotalAmount", "USD 1.000.000");
	ТаблицаДанных.Добавить(СтруктураДанных);
	НомерСтроки=НомерСтроки+1;

	СтруктураДанных = Новый Структура;
	СтруктураДанных.Вставить("RowNum", НомерСтроки);
	СтруктураДанных.Вставить("Account", "Account #7674839302 at Barclays bank");
	СтруктураДанных.Вставить("TotalAmount", "GBP 34.554");
	ТаблицаДанных.Добавить(СтруктураДанных);
	НомерСтроки=НомерСтроки+1;

	TemplateData.Вставить("ТаблицаДанных", ТаблицаДанных);

	Если Метаданные.Справочники.Найти("Организации") <> Неопределено Тогда
		Запрос = Новый Запрос;
		Запрос.Текст = "Выбрать первые 1 ссылка из справочник.организации";
		Рез = Запрос.Выполнить().Выгрузить();
	
		Реквизиты = "Наименование,Код";
		Орг = Новый Структура(Реквизиты);
		
		ЗначенияРеквизитов = ЗначенияРеквизитовОбъекта(Рез[0][0], Реквизиты);
		
		ЗаполнитьЗначенияСвойств(Орг, ЗначенияРеквизитов);
		
		TemplateData.Вставить("Организация", Орг);
		
	Иначе
		TemplateData.Вставить("Организация", Новый Структура("Код", "В конфигурации нет спр. Организации!"));
	КонецЕсли;
	
	// Для теста второго уровня вложенности коллекций
	TemplateData.Вставить("Контрагент", 
		Новый Структура("Имя,Адрес", "Банк ФК Открытие", 
			Новый Структура("Город", "Москва")));
			
	МассивЭлементов = Новый Массив;
	Для сч = 1 По 5 Цикл
		МассивЭлементов.Добавить(сч);	
	КонецЦикла; 
	TemplateData.Вставить("МассивЭлементов",МассивЭлементов);
	
	СписокДляТестаУсловия = Новый Массив;
	СписокДляТестаУсловия.Добавить("Ус");
	СписокДляТестаУсловия.Добавить("Элемент 2 списка 2");
	
	// таблицу с данными сделаем в виде массива структур, на всякий случай, чтобы и на клиенте работало
	ТаблицаДанныхДляТестаУсловия = Новый Массив;
	СтруктураДанных = Новый Структура;
	НомерСтроки = 1;
	СтруктураДанных.Вставить("RowNum", НомерСтроки);
	СтруктураДанных.Вставить("Amount", 5000);
	ТаблицаДанныхДляТестаУсловия.Добавить(СтруктураДанных);
	НомерСтроки=НомерСтроки+1;
	СтруктураДанных = Новый Структура;
	СтруктураДанных.Вставить("RowNum", НомерСтроки);
	СтруктураДанных.Вставить("Amount", 2000);
	ТаблицаДанныхДляТестаУсловия.Добавить(СтруктураДанных);
	НомерСтроки=НомерСтроки+1;
	
	TemplateData.Вставить("ТаблицаДанныхДляТестаУсловия",ТаблицаДанныхДляТестаУсловия);
	
	ВложеннаяТаблицаДанныхДляТестаУсловия = Новый Массив;
	СтруктураДанных = Новый Структура;
	НомерСтроки = 1;
	СтруктураДанных.Вставить("RowNum", НомерСтроки);
	СтруктураДанных.Вставить("Amount", 18);
	ВложеннаяТаблицаДанныхДляТестаУсловия.Добавить(СтруктураДанных);
	НомерСтроки=НомерСтроки+1;
	СтруктураДанных = Новый Структура;
	СтруктураДанных.Вставить("RowNum", НомерСтроки);
	СтруктураДанных.Вставить("Amount", 39);
	ВложеннаяТаблицаДанныхДляТестаУсловия.Добавить(СтруктураДанных);
	НомерСтроки=НомерСтроки+1;
	
	TemplateData.Вставить("ВложеннаяТаблицаДанныхДляТестаУсловия",ВложеннаяТаблицаДанныхДляТестаУсловия);
	
	
	TemplateData.Вставить("ReportDate", "2019-04-29T00:00:00.0");
	
	Возврат TemplateData;
	
EndFunction

// Перед вызовом этого метода в реквизит Объект.TemplateData следует поместить
// структуру с данными
Function GetTemplateDataIntoJSONServer() Export
	
	Writer = New JSONWriter;
	Writer.SetString();
	WriteJSON(Writer, TemplateData);
	
	JSONdata = Writer.Close();
	
	Return JSONdata;
	
EndFunction

#EndRegion

#Region Методы_из_БСП

// Функция "расщепляет" строку на подстроки, используя заданный
//      разделитель. Разделитель может иметь любую длину.
//      Если в качестве разделителя задан пробел, рядом стоящие пробелы
//      считаются одним разделителем, а ведущие и хвостовые пробелы параметра Стр
//      игнорируются.
//      Например,
//      РазложитьСтрокуВМассивПодстрок(",один,,,два", ",") возвратит массив значений из пяти элементов,
//      три из которых - пустые строки, а
//      РазложитьСтрокуВМассивПодстрок(" один   два", " ") возвратит массив значений из двух элементов
//
//  Параметры:
//      Стр -           строка, которую необходимо разложить на подстроки.
//                      Параметр передается по значению.
//      Разделитель -   строка-разделитель, по умолчанию - запятая.
//
//  Возвращаемое значение:
//      массив значений, элементы которого - подстроки
//
Функция РазложитьСтрокуВМассивПодстрок(Знач Стр, Разделитель = ",")
	
	МассивСтрок = Новый Массив();
	Если Разделитель = " " Тогда
		Стр = СокрЛП(Стр);
		Пока 1 = 1 Цикл
			Поз = Найти(Стр, Разделитель);
			Если Поз = 0 Тогда
				МассивСтрок.Добавить(Стр);
				Возврат МассивСтрок;
			КонецЕсли;
			МассивСтрок.Добавить(Лев(Стр, Поз - 1));
			Стр = СокрЛ(Сред(Стр, Поз));
		КонецЦикла;
	Иначе
		ДлинаРазделителя = СтрДлина(Разделитель);
		Пока 1 = 1 Цикл
			Поз = Найти(Стр, Разделитель);
			Если Поз = 0 Тогда
				Если (СокрЛП(Стр) <> "") Тогда
					МассивСтрок.Добавить(Стр);
				КонецЕсли;
				Возврат МассивСтрок;
			КонецЕсли;
			МассивСтрок.Добавить(Лев(Стр,Поз - 1));
			Стр = Сред(Стр, Поз + ДлинаРазделителя);
		КонецЦикла;
	КонецЕсли;
	
КонецФункции

// Структура, содержащая значения реквизитов, прочитанные из информационной базы по ссылке на объект.
//
// Если необходимо зачитать реквизит независимо от прав текущего пользователя,
// то следует использовать предварительный переход в привилегированный режим.
//
// Параметры:
//  Ссылка    - ЛюбаяСсылка - объект, значения реквизитов которого необходимо получить.
//            - Строка      - полное имя предопределенного элемента, значения реквизитов которого необходимо получить.
//  Реквизиты - Строка - имена реквизитов, перечисленные через запятую, в формате
//                       требований к свойствам структуры.
//                       Например, "Код, Наименование, Родитель".
//            - Структура, ФиксированнаяСтруктура - в качестве ключа передается
//                       псевдоним поля для возвращаемой структуры с результатом, а в качестве
//                       значения (опционально) фактическое имя поля в таблице.
//                       Если ключ задан, а значение не определено, то имя поля берется из ключа.
//            - Массив, ФиксированныйМассив - имена реквизитов в формате требований
//                       к свойствам структуры.
//  ВыбратьРазрешенные - Булево - если Истина, то запрос к объекту выполняется с учетом прав пользователя, и в случае,
//                                    - если есть ограничение на уровне записей, то все реквизиты вернутся 
//                                      со значением Неопределено;
//                                    - если нет прав для работы с таблицей, то возникнет исключение.
//                              - если Ложь, то возникнет исключение при отсутствии прав на таблицу 
//                                или любой из реквизитов.
//
// Возвращаемое значение:
//  Структура - содержит имена (ключи) и значения затребованных реквизитов.
//            - если в параметр Реквизиты передана пустая строка, то возвращается пустая структура.
//            - если в параметр Ссылка передана пустая ссылка, то возвращается структура, 
//              соответствующая именам реквизитов со значениями Неопределено.
//            - если в параметр Ссылка передана ссылка несуществующего объекта (битая ссылка), 
//              то все реквизиты вернутся со значением Неопределено.
//
Функция ЗначенияРеквизитовОбъекта(Ссылка, Знач Реквизиты, ВыбратьРазрешенные = Ложь) Экспорт
	
	// Если передано имя предопределенного. 
	Если ТипЗнч(Ссылка) = Тип("Строка") Тогда 
		
		ПолноеИмяПредопределенногоЭлемента = Ссылка;
		
		// Вычисление ссылки по имени предопределенного.
		// - дополнительно выполняет проверку метаданных предопределенного, выполняется предварительно.
		Попытка
			Ссылка = ОбщегоНазначенияКлиентСервер.ПредопределенныйЭлемент(ПолноеИмяПредопределенногоЭлемента);
		Исключение
			ТекстОшибки = СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку(
			НСтр("ru = 'Неверный первый параметр Ссылка:
			           |%1'"), КраткоеПредставлениеОшибки(ИнформацияОбОшибке()));
			ВызватьИсключение ТекстОшибки;
		КонецПопытки;
		
		// Разбор полного имени предопределенного.
		ЧастиПолногоИмени = СтрРазделить(ПолноеИмяПредопределенногоЭлемента, ".");
		ПолноеИмяОбъектаМетаданных = ЧастиПолногоИмени[0] + "." + ЧастиПолногоИмени[1];
		
		// Если предопределенный не создан в ИБ, то требуется выполнить проверку доступа к объекту.
		// В других сценариях проверка доступа выполняется в момент исполнения запроса.
		Если Ссылка = Неопределено Тогда 
			
			МетаданныеОбъекта = Метаданные.НайтиПоПолномуИмени(ПолноеИмяОбъектаМетаданных);
			
			Если Не ПравоДоступа("Чтение", МетаданныеОбъекта) Тогда 
				ВызватьИсключение СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку(
						НСтр("ru = 'Недостаточно прав для работы с таблицей ""%1""'"), ПолноеИмяОбъектаМетаданных);
			КонецЕсли;
			
		КонецЕсли;
		
	Иначе // Если передана ссылка.
		
		Попытка
			ПолноеИмяОбъектаМетаданных = Ссылка.Метаданные().ПолноеИмя(); 
		Исключение
			ВызватьИсключение НСтр("ru = 'Неверный первый параметр Ссылка: 
			                             |- Значение должно быть ссылкой или именем предопределенного элемента'");	
		КонецПопытки;
		
	КонецЕсли;
	
	// Разбор реквизитов, если второй параметр Строка.
	Если ТипЗнч(Реквизиты) = Тип("Строка") Тогда
		Если ПустаяСтрока(Реквизиты) Тогда
			Возврат Новый Структура;
		КонецЕсли;
		
		// Удаление пробелов.
		Реквизиты = СтрЗаменить(Реквизиты, " ", "");
		// Преобразование параметра в массив полей.
		Реквизиты = СтрРазделить(Реквизиты, ",");
	КонецЕсли;
	
	// Приведение реквизитов к единому формату.
	СтруктураПолей = Новый Структура;
	Если ТипЗнч(Реквизиты) = Тип("Структура")
		Или ТипЗнч(Реквизиты) = Тип("ФиксированнаяСтруктура") Тогда
		
		СтруктураПолей = Реквизиты;
		
	ИначеЕсли ТипЗнч(Реквизиты) = Тип("Массив")
		Или ТипЗнч(Реквизиты) = Тип("ФиксированныйМассив") Тогда
		
		Для Каждого Реквизит Из Реквизиты Цикл
			
			Попытка
				ПсевдонимПоля = СтрЗаменить(Реквизит, ".", "");
				СтруктураПолей.Вставить(ПсевдонимПоля, Реквизит);
			Исключение 
				// Если псевдоним не является ключом.
				
				// Поиск ошибки доступности полей.
				Результат = НайтиОшибкуДоступностиРеквизитовОбъекта(ПолноеИмяОбъектаМетаданных, Реквизиты);
				Если Результат.Ошибка Тогда 
					ВызватьИсключение СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку(
						НСтр("ru = 'Неверный второй параметр Реквизиты: %1'"), Результат.ОписаниеОшибки);
				КонецЕсли;
				
				// Не удалось распознать ошибку, проброс первичной ошибки.
				ВызватьИсключение;
			
			КонецПопытки;
		КонецЦикла;
	Иначе
		ВызватьИсключение СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку(
			НСтр("ru = 'Неверный тип второго параметра Реквизиты: %1'"), Строка(ТипЗнч(Реквизиты)));
	КонецЕсли;
	
	// Подготовка результата (после выполнения запроса переопределится).
	Результат = Новый Структура;
	
	// Формирование текста запроса к выбираемым полям.
	ТекстЗапросаПолей = "";
	Для каждого КлючИЗначение Из СтруктураПолей Цикл
		
		ИмяПоля = ?(ЗначениеЗаполнено(КлючИЗначение.Значение),
						КлючИЗначение.Значение,
						КлючИЗначение.Ключ);
		ПсевдонимПоля = КлючИЗначение.Ключ;
		
		ТекстЗапросаПолей = 
			ТекстЗапросаПолей + ?(ПустаяСтрока(ТекстЗапросаПолей), "", ",") + "
			|	" + ИмяПоля + " КАК " + ПсевдонимПоля;
		
		
		// Предварительное добавление поля по псевдониму в возвращаемый результат.
		Результат.Вставить(ПсевдонимПоля);
		
	КонецЦикла;
	
	// Если предопределенного нет в ИБ.
	// - приведение результата к отсутствию объекта в ИБ или передаче пустой ссылки.
	Если Ссылка = Неопределено Тогда 
		Возврат Результат;
	КонецЕсли;
	
	ТекстЗапроса = 
		"ВЫБРАТЬ " + ?(ВыбратьРазрешенные, "РАЗРЕШЕННЫЕ", "") + "
		|" + ТекстЗапросаПолей + "
		|ИЗ
		|	" + ПолноеИмяОбъектаМетаданных + " КАК Таблица
		|ГДЕ
		|	Таблица.Ссылка = &Ссылка
		|";
	
	// Выполнение запроса.
	Запрос = Новый Запрос;
	Запрос.УстановитьПараметр("Ссылка", Ссылка);
	Запрос.Текст = ТекстЗапроса;
	
	Попытка
		Выборка = Запрос.Выполнить().Выбрать();
	Исключение
		
		// Если реквизиты были переданы строкой, то они уже конвертированы в массив.
		// Если реквизиты - массив, оставляем без изменений.
		// Если реквизиты - структура - конвертируем в массив.
		// В остальных случаях уже было бы выброшено исключение.
		Если Тип("Структура") = ТипЗнч(Реквизиты) Тогда
			Реквизиты = Новый Массив;
			Для каждого КлючИЗначение Из СтруктураПолей Цикл
				ИмяПоля = ?(ЗначениеЗаполнено(КлючИЗначение.Значение),
							КлючИЗначение.Значение,
							КлючИЗначение.Ключ);
				Реквизиты.Добавить(ИмяПоля);
			КонецЦикла;
		КонецЕсли;
		
		// Поиск ошибки доступности полей.
		Результат = НайтиОшибкуДоступностиРеквизитовОбъекта(ПолноеИмяОбъектаМетаданных, Реквизиты);
		Если Результат.Ошибка Тогда 
			ВызватьИсключение СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку(
				НСтр("ru = 'Неверный второй параметр Реквизиты: %1'"), Результат.ОписаниеОшибки);
		КонецЕсли;
		
		// Не удалось распознать ошибку, проброс первичной ошибки.
		ВызватьИсключение;
		
	КонецПопытки;
	
	// Заполнение реквизитов.
	Если Выборка.Следующий() Тогда
		ЗаполнитьЗначенияСвойств(Результат, Выборка);
	КонецЕсли;
	
	Возврат Результат;
	
КонецФункции

// Значение реквизита, прочитанного из информационной базы по ссылке на объект.
//
// Если необходимо зачитать реквизит независимо от прав текущего пользователя,
// то следует использовать предварительный переход в привилегированный режим.
//
// Параметры:
//  Ссылка    - ЛюбаяСсылка - объект, значения реквизитов которого необходимо получить.
//            - Строка      - полное имя предопределенного элемента, значения реквизитов которого необходимо получить.
//  ИмяРеквизита       - Строка - имя получаемого реквизита.
//  ВыбратьРазрешенные - Булево - если Истина, то запрос к объекту выполняется с учетом прав пользователя, и в случае,
//                                    - если есть ограничение на уровне записей, то возвращается Неопределено;
//                                    - если нет прав для работы с таблицей, то возникнет исключение.
//                              - если Ложь, то возникнет исключение при отсутствии прав на таблицу
//                                или любой из реквизитов.
//
// Возвращаемое значение:
//  Произвольный - зависит от типа значения прочитанного реквизита.
//               - если в параметр Ссылка передана пустая ссылка, то возвращается Неопределено.
//               - если в параметр Ссылка передана ссылка несуществующего объекта (битая ссылка), 
//                 то возвращается Неопределено.
//
Функция ЗначениеРеквизитаОбъекта(Ссылка, ИмяРеквизита, ВыбратьРазрешенные = Ложь) Экспорт
	
	Если ПустаяСтрока(ИмяРеквизита) Тогда 
		ВызватьИсключение НСтр("ru = 'Неверный второй параметр ИмяРеквизита: 
		                             |- Имя реквизита должно быть заполнено'");
	КонецЕсли;
	
	Результат = ЗначенияРеквизитовОбъекта(Ссылка, ИмяРеквизита, ВыбратьРазрешенные);
	Возврат Результат[СтрЗаменить(ИмяРеквизита, ".", "")];
	
КонецФункции 

// Значения реквизитов, прочитанные из информационной базы для нескольких объектов.
//
//  Если необходимо зачитать реквизит независимо от прав текущего пользователя,
//  то следует использовать предварительный переход в привилегированный режим.
//
// Параметры:
//  Ссылки - Массив - массив ссылок на объекты одного типа.
//                          Значения массива должны быть ссылками на объекты одного типа.
//                          если массив пуст, то результатом будет пустое соответствие.
//  Реквизиты - Строка - имена реквизитов перечисленные через запятую, в формате требований к свойствам
//                             структуры. Например, "Код, Наименование, Родитель".
//  ВыбратьРазрешенные - Булево - если Истина, то запрос к объектам выполняется с учетом прав пользователя, и в случае,
//                                    - если какой-либо объект будет исключен из выборки по правам, то этот объект
//                                      будет исключен и из результата;
//                              - если Ложь, то возникнет исключение при отсутствии прав на таблицу
//                                или любой из реквизитов.
//
// Возвращаемое значение:
//  Соответствие - список объектов и значений их реквизитов:
//   * Ключ - ЛюбаяСсылка - ссылка на объект;
//   * Значение - Структура - значения реквизитов:
//    ** Ключ - Строка - имя реквизита;
//    ** Значение - Произвольный - значение реквизита.
// 
Функция ЗначенияРеквизитовОбъектов(Ссылки, Знач Реквизиты, ВыбратьРазрешенные = Ложь) Экспорт
	
	Если ПустаяСтрока(Реквизиты) Тогда 
		ВызватьИсключение НСтр("ru = 'Неверный второй параметр Реквизиты: 
		                             |- Поле объекта должно быть указано'");
	КонецЕсли;
	
	Если СтрНайти(Реквизиты, ".") <> 0 Тогда 
		ВызватьИсключение НСтр("ru = 'Неверный второй параметр Реквизиты: 
		                             |- Обращение через точку не поддерживается'");
	КонецЕсли;
	
	ЗначенияРеквизитов = Новый Соответствие;
	Если Ссылки.Количество() = 0 Тогда
		Возврат ЗначенияРеквизитов;
	КонецЕсли;
	
	ПерваяСсылка = Ссылки[0];
	
	Попытка
		ПолноеИмяОбъектаМетаданных = ПерваяСсылка.Метаданные().ПолноеИмя();
	Исключение
		ВызватьИсключение НСтр("ru = 'Неверный первый параметр Ссылки: 
		                             |- Значения массива должны быть ссылками'");
	КонецПопытки;
	
	Запрос = Новый Запрос;
	Запрос.Текст =
		"ВЫБРАТЬ " + ?(ВыбратьРазрешенные, "РАЗРЕШЕННЫЕ", "") + "
		|	Ссылка КАК Ссылка, " + Реквизиты + "
		|ИЗ
		|	" + ПолноеИмяОбъектаМетаданных + " КАК Таблица
		|ГДЕ
		|	Таблица.Ссылка В (&Ссылки)";
	Запрос.УстановитьПараметр("Ссылки", Ссылки);
	
	Попытка
		Выборка = Запрос.Выполнить().Выбрать();
	Исключение
		
		// Удаление пробелов.
		Реквизиты = СтрЗаменить(Реквизиты, " ", "");
		// Преобразование параметра в массив полей.
		Реквизиты = СтрРазделить(Реквизиты, ",");
		
		// Поиск ошибки доступности полей.
		Результат = НайтиОшибкуДоступностиРеквизитовОбъекта(ПолноеИмяОбъектаМетаданных, Реквизиты);
		Если Результат.Ошибка Тогда 
			ВызватьИсключение СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку(
				НСтр("ru = 'Неверный второй параметр Реквизиты: %1'"), Результат.ОписаниеОшибки);
		КонецЕсли;
		
		// Не удалось распознать ошибку, проброс первичной ошибки.
		ВызватьИсключение;
		
	КонецПопытки;
	
	Пока Выборка.Следующий() Цикл
		Результат = Новый Структура(Реквизиты);
		ЗаполнитьЗначенияСвойств(Результат, Выборка);
		ЗначенияРеквизитов[Выборка.Ссылка] = Результат;
	КонецЦикла;
	
	Возврат ЗначенияРеквизитов;
	
КонецФункции

// Значения реквизита, прочитанного из информационной базы для нескольких объектов.
//
//  Если необходимо зачитать реквизит независимо от прав текущего пользователя,
//  то следует использовать предварительный переход в привилегированный режим.
//
// Параметры:
//  МассивСсылок       - Массив - массив ссылок на объекты одного типа.
//                                Значения массива должны быть ссылками на объекты одного типа.
//  ИмяРеквизита       - Строка - например, "Код".
//  ВыбратьРазрешенные - Булево - если Истина, то запрос к объектам выполняется с учетом прав пользователя, и в случае,
//                                    - если какой-либо объект будет исключен из выборки по правам, то этот объект
//                                      будет исключен и из результата;
//                              - если Ложь, то возникнет исключение при отсутствии прав на таблицу
//                                или любой из реквизитов.
//
// Возвращаемое значение:
//  Соответствие - Ключ - ссылка на объект, Значение - значение прочитанного реквизита.
//      * Ключ     - ссылка на объект, 
//      * Значение - значение прочитанного реквизита.
// 
Функция ЗначениеРеквизитаОбъектов(МассивСсылок, ИмяРеквизита, ВыбратьРазрешенные = Ложь) Экспорт
	
	Если ПустаяСтрока(ИмяРеквизита) Тогда 
		ВызватьИсключение НСтр("ru = 'Неверный второй параметр ИмяРеквизита: 
		                             |- Имя реквизита должно быть заполнено'");
	КонецЕсли;
	
	ЗначенияРеквизитов = ЗначенияРеквизитовОбъектов(МассивСсылок, ИмяРеквизита, ВыбратьРазрешенные);
	Для каждого Элемент Из ЗначенияРеквизитов Цикл
		ЗначенияРеквизитов[Элемент.Ключ] = Элемент.Значение[ИмяРеквизита];
	КонецЦикла;
		
	Возврат ЗначенияРеквизитов;
	
КонецФункции

// Выполняет поиск проверяемых выражений среди реквизитов объекта метаданных.
// 
// Параметры:
//  ПолноеИмяОбъектаМетаданных - Строка - полное имя проверяемого объекта.
//  ПроверяемыеВыражения       - Массив - имена полей или проверяемые выражения объекта метаданных.
// 
// Возвращаемое значение:
//  Структура - Результат проверки.
//  * Ошибка         - Булево - Найдена ошибка.
//  * ОписаниеОшибки - Строка - Описание найденных ошибок.
//
// Пример:
//  
// Реквизиты = Новый Массив;
// Реквизиты.Добавить("Номер");
// Реквизиты.Добавить("Валюта.НаименованиеПолное");
//
// Результат = ОбщегоНазначения.НайтиОшибкуДоступностиРеквизитовОбъекта("Документ._ДемоЗаказПокупателя", Реквизиты);
//
// Если Результат.Ошибка Тогда
//     ВызватьИсключение Результат.ОписаниеОшибки;
// КонецЕсли;
//
Функция НайтиОшибкуДоступностиРеквизитовОбъекта(ПолноеИмяОбъектаМетаданных, ПроверяемыеВыражения)
	
	МетаданныеОбъекта = Метаданные.НайтиПоПолномуИмени(ПолноеИмяОбъектаМетаданных);
	
	Если МетаданныеОбъекта = Неопределено Тогда 
		Возврат Новый Структура("Ошибка, ОписаниеОшибки", Истина, 
			СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку(
				НСтр("ru = 'Ошибка получения метаданных ""%1""'"), ПолноеИмяОбъектаМетаданных));
	КонецЕсли;

	// Разрешение вызова из безопасного режима внешней обработки или расширения.
	// Информация о доступности полей источника схемы при проверке метаданных не является секретной.
	УстановитьОтключениеБезопасногоРежима(Истина);
	УстановитьПривилегированныйРежим(Истина);
	
	Схема = Новый СхемаЗапроса;
	Пакет = Схема.ПакетЗапросов.Добавить(Тип("ЗапросВыбораСхемыЗапроса"));
	Оператор = Пакет.Операторы.Получить(0);
	
	Источник = Оператор.Источники.Добавить(ПолноеИмяОбъектаМетаданных, "Таблица");
	ТекстОшибки = "";
	
	Для Каждого ТекущееВыражение Из ПроверяемыеВыражения Цикл
		
		Если Не ПолеИсточникаСхемыЗапросаДоступно(Источник, ТекущееВыражение) Тогда 
			ТекстОшибки = ТекстОшибки + Символы.ПС + СтроковыеФункцииКлиентСервер.ПодставитьПараметрыВСтроку(
				НСтр("ru = '- Поле объекта ""%1"" не найдено'"), ТекущееВыражение);
		КонецЕсли;
		
	КонецЦикла;
		
	Возврат Новый Структура("Ошибка, ОписаниеОшибки", Не ПустаяСтрока(ТекстОшибки), ТекстОшибки);
	
КонецФункции

// Используется в НайтиОшибкуДоступностиРеквизитовОбъекта.
// Выполняет проверку доступности поля проверяемого выражения в источнике оператора схемы запроса.
//
Функция ПолеИсточникаСхемыЗапросаДоступно(ИсточникОператора, ПроверяемоеВыражение)
	
	ЧастиИмениПоля = СтрРазделить(ПроверяемоеВыражение, ".");
	ДоступныеПоля = ИсточникОператора.Источник.ДоступныеПоля;
	
	ТекущаяЧастьИмениПоля = 0;
	Пока ТекущаяЧастьИмениПоля < ЧастиИмениПоля.Количество() Цикл 
		
		ТекущееПоле = ДоступныеПоля.Найти(ЧастиИмениПоля.Получить(ТекущаяЧастьИмениПоля)); 
		
		Если ТекущееПоле = Неопределено Тогда 
			Возврат Ложь;
		КонецЕсли;
		
		// Инкрементация следующей части имени поля и соответствующего списка доступности полей.
		ТекущаяЧастьИмениПоля = ТекущаяЧастьИмениПоля + 1;
		ДоступныеПоля = ТекущееПоле.Поля;
		
	КонецЦикла;
	
	Возврат Истина;
	
КонецФункции

#EndRegion

mIterators 	= New Map;
mStack 		= New Array;
SearchingNextElse = False;

