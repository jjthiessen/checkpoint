open FsToolkit.ErrorHandling
// open FsToolkit.ErrorHandling.TaskResult

open Microsoft.Playwright

open System
open System.Threading.Tasks

type PlaywrightError = string

let timeout = 5_000f

let setup () : Task<Result<(IPlaywright * IBrowser * IBrowserContext), PlaywrightError>> =
    taskResult {
        let! playwright = Playwright.CreateAsync ()
        let! browser = playwright.Chromium.LaunchAsync(BrowserTypeLaunchOptions(Headless = false, SlowMo = 2000f))
        let! context = browser.NewContextAsync ()
        return (playwright, browser, context)
    }

let openLogin (url: string) (context: IBrowserContext) : Task<Result<IPage, PlaywrightError>> =
    taskResult {
        printfn "Attempting to navigate and get popup..."
        let! initialPage = context.NewPageAsync()

        let popupTask = context.WaitForPageAsync(BrowserContextWaitForPageOptions(Timeout = timeout))

        let! _ = initialPage.GotoAsync(url, PageGotoOptions(Timeout = timeout))

        let! popupPage = popupTask
        printfn $"Popup page captured: {popupPage.Url}"

        let! _ = popupPage.WaitForLoadStateAsync(LoadState.Load, PageWaitForLoadStateOptions(Timeout = timeout))
        printfn "Popup page loaded."

        return popupPage
    }

let doLogin (page: IPage) : Task<Result<IPage, PlaywrightError>> =
    let username = Console.ReadLine ()
    let password = Console.ReadLine ()
    let totp = Console.ReadLine ()

    taskResult {
        do!
            System.Text.RegularExpressions.Regex.IsMatch(page.Url, @"^https://login\.microsoftonline\.com/") // DO NOT DELETE THE TRAILING SLASH!
            |> Result.requireTrue "The SAML Service Provider appears to have not redirected to Microsoft. It is not safe to continue."

        do! page.GetByPlaceholder("Email, phone, or Skype").FillAsync username
        do! page.GetByRole(AriaRole.Button, PageGetByRoleOptions(Name = "Next")).ClickAsync ()

        do! page.GetByPlaceholder("Password").FillAsync password
        do! page.GetByRole(AriaRole.Button, PageGetByRoleOptions(Name = "Sign in")).ClickAsync ()

        do! page.GetByPlaceholder("Code").FillAsync totp
        do! page.GetByRole(AriaRole.Button, PageGetByRoleOptions(Name = "Verify")).ClickAsync ()

        do! page.GetByText("Don't show this again").ClickAsync ()
        do! page.GetByRole(AriaRole.Button, PageGetByRoleOptions(Name = "Yes")).ClickAsync ()

        do! page.WaitForLoadStateAsync(LoadState.Load, PageWaitForLoadStateOptions(Timeout = timeout))

        return page
    }

// For troubleshooting
let takeScreenshot (page: IPage) : Task<Result<string, PlaywrightError>> =
    let path = "./screenshot.png"

    taskResult {
        printfn $"Attempting screenshot: {path}"
        let! _ = page.ScreenshotAsync(PageScreenshotOptions(Path = path))
        printfn $"Screenshot success: {path}"
        return path
    } |> TaskResult.mapError (fun msg -> $"Screenshot failed: {msg}")

[<EntryPoint>]
let main (argv: string array) =
    let pipeline =
        taskResult {
            let! url =
                argv.Length = 1
                |> Result.requireTrue $"There should be exactly one argument to {System.AppDomain.CurrentDomain.FriendlyName} — the URL that triggers the SAML SP-initiated auth flow."
                |> Result.map (fun _ -> argv[0])

            let! (_playwright, _browser, _context) = setup ()
            use playwright = _playwright
            use browser = _browser
            use context = _context

            printfn "Setup successful. Running main pipeline..."
            return!
                context
                |> openLogin url
                |> TaskResult.bind doLogin
        }

    match pipeline.Result with
    | Ok msg ->
        printfn $"{msg}"
        printfn "Script finished."
        0
    | Error err ->
        printfn $"BLARG!: {err}"
        1
