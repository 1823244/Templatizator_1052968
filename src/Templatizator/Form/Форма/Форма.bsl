// Схема работы программно.

// Об = Обработки.CreateHTMLbyTemplate.Создать();

// Вариант 1. Передается структура с данными
//  Можно использовать объекты базы данных

// СтруктураСДанными = Новый Структура;
// СтруктураСДанными.Вставить("Title", "Creating HTML by templates in Django/Flask style");
// Список1 = Новый Массив;
// Список1.Добавить("Элемент 1 списка 1");
// Список1.Добавить("Элемент 2 списка 1");
// СтруктураСДанными.Вставить("Список", Список1);
// Организация = Справочники.Организации.НайтиПоКоду("000000001");
// СтруктураСДанными.Вставить("Организация", Организация);

// Об.TemplateData = СтруктураСДанными;
// Об.TemplateText = ТекстШаблонаВВидеСтроки;
// РезультатHTML = Об.СоздатьHTMLнаСервере();

// Вариант 2. Передается JSON с данными
//  Можно использовать только простые типы (число, строка...)
//  плюс массив, структура

// Об.JSON = JSONСДанными;
// Об.TemplateText = ТекстШаблонаВВидеСтроки;
// РезультатHTML = Об.СоздатьHTMLнаСервере();

// Приоритет имеет Вариант 1, если передаются оба объекта,
// структура и JSON.

// Схема работы интерактивно.

// ПриСозданииНаСервере
// 	Создаются тестовые данные для шаблона: Объект.TemplateData = CreateTemplateData();
// 	Эти данные помещаются в текст JSON: GetTemplateDataIntoJSONServer();
// Объект.TemplateData очищается.

// Создание HTML
// 	JSON-данные помещаются в реквизит обработки JSON
// 	Управление передается в модуль объекта
// 	На сервере JSON превращается в структуру,
// 	которая затем используется для заполнения шаблона.

// Процесс отладки шаблона.

//	Поместить текст своего шаблона в OnOpen()
//	Создание своих данные - CreateTemplateData()
//	Если нужно использовать объекты базы данных,
//	то единственный путь - использовать обработку
//	программно по варианту 1.


////////////////////////////////////////////////////////////

&AtServer
Procedure ПриСозданииНаСервере(Отказ, СтандартнаяОбработка)
	
	Obj = FormAttributeToValue("Объект");
	t = Obj.GetTemplate("TemplateForTest");
	TemplateText=t.GetText();
	
	Объект.TemplateData = Obj.CreateTemplateData();
	
	// show template data on the form
	Объект.JSON = Obj.GetTemplateDataIntoJSONServer();
	
	Объект.TemplateData = Undefined;
	
EndProcedure

////////////////////////////////////////////////////////////


&НаКлиенте
Процедура ПриОткрытии(Отказ)
	CreateHTMLServer();
КонецПроцедуры

////////////////////////////////////////////////////////////

&AtClient
Procedure CreateHTML(Command)
	
	CreateHTMLServer();
	
EndProcedure

////////////////////////////////////////////////////////////

&AtServer
Procedure CreateHTMLServer()
	
	DataProc 				= FormAttributeToValue("Объект");
	DataProc.TemplateText 	= TemplateText;
	// already set on open
	//DataProc.JSON			= JSONdata;
	
	ResultHTML 				= DataProc.CreateHTMLServer( "ReportDate" );
	
	// можно проверить работу агоритма дерева.
	// после работы этих четырех строчек кода в реквизите формы TestTemplateTree
	// должен быть текст исходного шаблона
	//DataProc.CopyTemplateTextToVariable();
	//TestTemplateTree 		= "";
	//TemplateTree 			= DataProc.CreateTemplateTree( Undefined );
	//ExecTestTemplateTree( TemplateTree.Rows );
	
	TestTemplateTree = ResultHTML;
	
EndProcedure

////////////////////////////////////////////////////////////

&AtServer
Procedure ExecTestTemplateTree( Rows ) Export
	
	For Each Str In Rows Do
		
		TestTemplateTree = TestTemplateTree + Str.Текст;
		
		ExecTestTemplateTree( Str.Rows );
		
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////
 
&AtClient
Procedure ShowTemplateTree(Команда)
	ТабДок = ПоказатьДеревоШаблонаНаСервере();
	ТабДок.Показать("Дерево шаблона");
EndProcedure

////////////////////////////////////////////////////////////

&AtServer
Функция ПоказатьДеревоШаблонаНаСервере()
	Об = FormAttributeToValue("Объект");
	Об.TemplateText = TemplateText;
	Об.CopyTemplateTextToVariable();
	ДеревоЗначений = Об.CreateTemplateTree( Undefined );
	ТабДок = ОбщийМодуль1Сервер.ВывестиДеревоЧерезУниверсальныйМакет_Сервер(ДеревоЗначений,,, );
	Возврат ТабДок;
КонецФункции

////////////////////////////////////////////////////////////

